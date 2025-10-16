import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { v4 as uuidv4 } from 'uuid';

const app = new Hono();

app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// 工具函数
function generateCode(length = 6) {
  let result = '';
  for (let i = 0; i < length; i++) {
    result += Math.floor(Math.random() * 10).toString();
  }
  return result;
}

// 基础限流中间件（基于 KV 的滑动窗口桶）
function rateLimit(name, limit, windowSec) {
  return rateLimitWithKey(name, limit, windowSec, (c) => c.req.header('cf-connecting-ip') || c.req.header('x-forwarded-for') || 'unknown');
}

function rateLimitWithKey(name, limit, windowSec, keyResolver) {
  return async (c, next) => {
    try {
      const who = await Promise.resolve(keyResolver(c));
      const nowBucket = Math.floor(Date.now() / 1000 / windowSec);
      const key = `ratelimit:${name}:${who}:${nowBucket}`;

      const currentStr = await c.env.FILECODEBOX_KV.get(key);
      const current = currentStr ? parseInt(currentStr, 10) : 0;
      if (current >= limit) {
        return c.json({ code: 429, detail: '请求过于频繁，请稍后再试' }, 429);
      }

      await c.env.FILECODEBOX_KV.put(key, String(current + 1), { expirationTtl: windowSec + 10 });
    } catch (_) {
      // 限流失败时不阻断主流程
    }
    await next();
  };
}

function calculateExpireTime(value, style) {
  const now = new Date();
  switch (style) {
    case 'minute':
      return new Date(now.getTime() + value * 60 * 1000);
    case 'hour':
      return new Date(now.getTime() + value * 60 * 60 * 1000);
    case 'day':
      return new Date(now.getTime() + value * 24 * 60 * 60 * 1000);
    case 'forever':
      return null;
    default:
      return new Date(now.getTime() + 24 * 60 * 60 * 1000);
  }
}

// 自动清理过期文件函数
async function cleanupExpiredFiles(env) {
  console.log('🧹 Starting automatic cleanup process...');
  
  try {
    const { keys } = await env.FILECODEBOX_KV.list({ prefix: 'file:' });
    
    if (keys.length === 0) {
      console.log('📝 No files to check');
      return { total: 0, cleaned: 0, errors: 0 };
    }
    
    console.log(`📋 Found ${keys.length} files to check for expiration`);
    
    let totalChecked = 0;
    let cleanedCount = 0;
    let errorCount = 0;
    const now = new Date();
    
    const batchSize = 10;
    for (let i = 0; i < keys.length; i += batchSize) {
      const batch = keys.slice(i, i + batchSize);
      
      await Promise.all(batch.map(async (key) => {
        try {
          totalChecked++;
          const code = key.name.replace('file:', '');
          
          const fileDataStr = await env.FILECODEBOX_KV.get(key.name);
          if (!fileDataStr) {
            return;
          }
          
          const fileData = JSON.parse(fileDataStr);
          
          if (fileData.expired_at) {
            const expireTime = new Date(fileData.expired_at);
            
            if (expireTime <= now) {
              console.log(`⏰ File ${code} expired, cleaning up...`);
              
              await env.FILECODEBOX_KV.delete(key.name);
              console.log(`🗑️ Deleted KV record: ${code}`);
              
              if (fileData.uuid_file_name) {
                try {
                  await env.FILECODEBOX_R2.delete(fileData.uuid_file_name);
                  console.log(`🗑️ Deleted R2 file: ${fileData.uuid_file_name}`);
                } catch (r2Error) {
                  console.error(`❌ Failed to delete R2 file:`, r2Error);
                  errorCount++;
                }
              }
              
              cleanedCount++;
            }
          }
          
        } catch (error) {
          console.error(`❌ Error processing file:`, error);
          errorCount++;
        }
      }));
    }
    
    const result = {
      total: totalChecked,
      cleaned: cleanedCount,
      errors: errorCount,
      timestamp: now.toISOString()
    };
    
    console.log(`🎉 Cleanup completed: ${JSON.stringify(result)}`);
    return result;
    
  } catch (error) {
    console.error('💥 Fatal error during cleanup:', error);
    return { total: 0, cleaned: 0, errors: 1, error: error.message };
  }
}

// API 路由
app.get('/', (c) => {
  return c.html(`
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>FileCodeBox - 文件快传</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
            .container { background: white; border-radius: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); padding: 2rem; max-width: 500px; width: 90%; }
            h1 { text-align: center; color: #333; margin-bottom: 2rem; font-size: 2rem; }
            .upload-area { border: 2px dashed #ddd; border-radius: 10px; padding: 2rem; text-align: center; margin-bottom: 1rem; transition: all 0.3s; }
            .upload-area:hover { border-color: #667eea; background: #f8f9ff; }
            .upload-area.dragover { border-color: #667eea; background: #f0f4ff; }
            .btn { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 12px 24px; border-radius: 8px; cursor: pointer; font-size: 1rem; transition: transform 0.2s; }
            .btn:hover { transform: translateY(-2px); }
            .form-group { margin-bottom: 1rem; }
            label { display: block; margin-bottom: 0.5rem; color: #555; font-weight: 500; }
            input, select, textarea { width: 100%; padding: 12px; border: 2px solid #eee; border-radius: 8px; font-size: 1rem; transition: border-color 0.3s; }
            input:focus, select:focus, textarea:focus { outline: none; border-color: #667eea; }
            .result { margin-top: 1rem; padding: 1rem; background: #f8f9fa; border-radius: 8px; display: none; }
            .error { background: #ffe6e6; color: #d63384; }
            .success { background: #e6f7e6; color: #198754; }
            .code-display { font-family: 'Courier New', monospace; font-size: 1.5rem; font-weight: bold; text-align: center; padding: 1rem; background: #f0f4ff; border-radius: 8px; margin: 1rem 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>📦 FileCodeBox</h1>
            
            <div class="upload-area" id="uploadArea">
                <p>📁 拖拽文件到此处或点击选择文件</p>
                <input type="file" id="fileInput" style="display: none;">
                <button class="btn" onclick="document.getElementById('fileInput').click()">选择文件</button>
            </div>
            
            <div class="form-group">
                <label for="expireValue">过期时间:</label>
                <div style="display: flex; gap: 10px;">
                    <input type="number" id="expireValue" value="1" min="1" style="flex: 1;">
                    <select id="expireStyle" style="flex: 1;">
                        <option value="day">天</option>
                        <option value="hour">小时</option>
                        <option value="minute">分钟</option>
                        <option value="forever">永久</option>
                    </select>
                </div>
            </div>
            
            <div class="form-group">
                <label for="textContent">或输入文本内容:</label>
                <textarea id="textContent" rows="4" placeholder="输入要分享的文本内容..."></textarea>
            </div>
            
            <button class="btn" onclick="uploadFile()" style="width: 100%;">🚀 上传并生成取件码</button>
            
            <div id="result" class="result"></div>
            
            <hr style="margin: 2rem 0; border: none; border-top: 1px solid #eee;">
            
            <div class="form-group">
                <label for="downloadCode">输入取件码下载:</label>
                <div style="display: flex; gap: 10px;">
                    <input type="text" id="downloadCode" placeholder="输入6位取件码">
                    <button class="btn" onclick="downloadFile()">📥 下载</button>
                </div>
            </div>
        </div>
        
        <script>
            const uploadArea = document.getElementById('uploadArea');
            const fileInput = document.getElementById('fileInput');
            const result = document.getElementById('result');
            
            // 拖拽上传
            uploadArea.addEventListener('dragover', (e) => {
                e.preventDefault();
                uploadArea.classList.add('dragover');
            });
            
            uploadArea.addEventListener('dragleave', () => {
                uploadArea.classList.remove('dragover');
            });
            
            uploadArea.addEventListener('drop', (e) => {
                e.preventDefault();
                uploadArea.classList.remove('dragover');
                const files = e.dataTransfer.files;
                if (files.length > 0) {
                    fileInput.files = files;
                }
            });
            
            async function uploadFile() {
                const file = fileInput.files[0];
                const textContent = document.getElementById('textContent').value;
                const expireValue = document.getElementById('expireValue').value;
                const expireStyle = document.getElementById('expireStyle').value;
                
                if (!file && !textContent) {
                    showResult('请选择文件或输入文本内容', 'error');
                    return;
                }
                
                const formData = new FormData();
                if (file) {
                    formData.append('file', file);
                } else {
                    formData.append('text', textContent);
                }
                formData.append('expired_style', expireStyle);
                formData.append('expired_value', expireValue);
                
                try {
                    const response = await fetch('/share', {
                        method: 'POST',
                        body: formData
                    });
                    
                    const data = await response.json();
                    
                    if (data.code === 0) {
                        showResult(\`
                            <div class="code-display">\${data.data.code}</div>
                            <p>✅ 上传成功！取件码: <strong>\${data.data.code}</strong></p>
                            <p>📅 过期时间: \${data.data.expired_at || '永不过期'}</p>
                        \`, 'success');
                    } else {
                        showResult('❌ ' + data.detail, 'error');
                    }
                } catch (error) {
                    showResult('❌ 上传失败: ' + error.message, 'error');
                }
            }
            
            async function downloadFile() {
                const code = document.getElementById('downloadCode').value;
                if (!code) {
                    showResult('请输入取件码', 'error');
                    return;
                }
                
                try {
                    const response = await fetch(\`/s/\${code}\`);
                    
                    if (response.ok) {
                        const contentType = response.headers.get('content-type');
                        if (contentType && contentType.includes('application/json')) {
                            const data = await response.json();
                            if (data.type === 'text') {
                                showResult(\`
                                    <h4>📝 文本内容:</h4>
                                    <pre style="white-space: pre-wrap; background: #f8f9fa; padding: 1rem; border-radius: 4px; margin-top: 0.5rem;">\${data.text}</pre>
                                \`, 'success');
                            }
                        } else {
                            // 文件下载
                            const blob = await response.blob();
                            const url = window.URL.createObjectURL(blob);
                            const a = document.createElement('a');
                            a.href = url;
                            a.download = response.headers.get('content-disposition')?.split('filename=')[1]?.replace(/"/g, '') || 'download';
                            document.body.appendChild(a);
                            a.click();
                            document.body.removeChild(a);
                            window.URL.revokeObjectURL(url);
                            showResult('✅ 文件下载开始', 'success');
                        }
                    } else {
                        const data = await response.json();
                        showResult('❌ ' + (data.detail || '下载失败'), 'error');
                    }
                } catch (error) {
                    showResult('❌ 下载失败: ' + error.message, 'error');
                }
            }
            
            function showResult(message, type) {
                result.innerHTML = message;
                result.className = \`result \${type}\`;
                result.style.display = 'block';
            }
        </script>
    </body>
    </html>
  `);
});

// 上传文件或文本
app.post('/share', rateLimit('upload', 10, 60), async (c) => {
  try {
    const formData = await c.req.formData();
    const file = formData.get('file');
    const text = formData.get('text');
    const expiredStyle = formData.get('expired_style') || 'day';
    const expiredValue = parseInt(formData.get('expired_value') || '1');

    if (!file && !text) {
      return c.json({ code: 400, detail: '请提供文件或文本内容' }, 400);
    }

    // 生成取件码
    let code;
    let attempts = 0;
    do {
      code = generateCode(6);
      attempts++;
      if (attempts > 10) {
        return c.json({ code: 500, detail: '生成取件码失败，请重试' }, 500);
      }
    } while (await c.env.FILECODEBOX_KV.get(`file:${code}`));

    const expiredAt = calculateExpireTime(expiredValue, expiredStyle);
    const fileData = {
      code,
      created_at: new Date().toISOString(),
      expired_at: expiredAt ? expiredAt.toISOString() : null,
    };

    if (file) {
      // 处理文件上传
      const maxFileSize = parseInt(c.env.MAX_FILE_SIZE || '90') * 1024 * 1024;
      if (file.size > maxFileSize) {
        return c.json({ 
          code: 413, 
          detail: `文件大小超过限制 (${Math.round(maxFileSize / 1024 / 1024)}MB)` 
        }, 413);
      }

      const uuidFileName = uuidv4() + '_' + file.name;
      
      // 上传到 R2
      await c.env.FILECODEBOX_R2.put(uuidFileName, file.stream(), {
        httpMetadata: {
          contentType: file.type || 'application/octet-stream',
          contentDisposition: `attachment; filename="${encodeURIComponent(file.name)}"`,
        },
      });

      fileData.type = 'file';
      fileData.filename = file.name;
      fileData.uuid_file_name = uuidFileName;
      fileData.size = file.size;
      fileData.content_type = file.type;
    } else {
      // 处理文本上传
      const maxTextSize = parseInt(c.env.MAX_TEXT_SIZE || '1') * 1024 * 1024;
      if (text.length > maxTextSize) {
        return c.json({ 
          code: 413, 
          detail: `文本大小超过限制 (${Math.round(maxTextSize / 1024 / 1024)}MB)` 
        }, 413);
      }

      fileData.type = 'text';
      fileData.text = text;
    }

    // 保存到 KV
    const ttl = expiredAt ? Math.floor((expiredAt.getTime() - Date.now()) / 1000) : undefined;
    await c.env.FILECODEBOX_KV.put(
      `file:${code}`, 
      JSON.stringify(fileData), 
      ttl ? { expirationTtl: ttl } : undefined
    );

    return c.json({
      code: 0,
      data: {
        code,
        expired_at: expiredAt ? expiredAt.toISOString() : null,
      },
    });
  } catch (error) {
    console.error('Upload error:', error);
    return c.json({ code: 500, detail: '上传失败' }, 500);
  }
});

// 下载文件
app.get('/s/:code', rateLimit('download', 60, 60), async (c) => {
  try {
    const code = c.req.param('code');
    
    if (!/^\d{6}$/.test(code)) {
      return c.json({ code: 400, detail: '无效的取件码格式' }, 400);
    }

    const fileDataStr = await c.env.FILECODEBOX_KV.get(`file:${code}`);
    if (!fileDataStr) {
      return c.json({ code: 404, detail: '取件码不存在或已过期' }, 404);
    }

    const fileData = JSON.parse(fileDataStr);

    if (fileData.type === 'text') {
      return c.json({
        type: 'text',
        text: fileData.text,
        created_at: fileData.created_at,
        expired_at: fileData.expired_at,
      });
    } else {
      // 从 R2 获取文件
      const object = await c.env.FILECODEBOX_R2.get(fileData.uuid_file_name);
      if (!object) {
        return c.json({ code: 404, detail: '文件不存在' }, 404);
      }

      return new Response(object.body, {
        headers: {
          'Content-Type': fileData.content_type || 'application/octet-stream',
          'Content-Disposition': `attachment; filename="${encodeURIComponent(fileData.filename)}"`,
          'Content-Length': fileData.size.toString(),
        },
      });
    }
  } catch (error) {
    console.error('Download error:', error);
    return c.json({ code: 500, detail: '下载失败' }, 500);
  }
});

// 获取文件信息
app.get('/info/:code', rateLimit('info', 120, 60), async (c) => {
  try {
    const code = c.req.param('code');
    
    if (!/^\d{6}$/.test(code)) {
      return c.json({ code: 400, detail: '无效的取件码格式' }, 400);
    }

    const fileDataStr = await c.env.FILECODEBOX_KV.get(`file:${code}`);
    if (!fileDataStr) {
      return c.json({ code: 404, detail: '取件码不存在或已过期' }, 404);
    }

    const fileData = JSON.parse(fileDataStr);
    
    return c.json({
      code: 0,
      data: {
        type: fileData.type,
        filename: fileData.filename,
        size: fileData.size,
        created_at: fileData.created_at,
        expired_at: fileData.expired_at,
      },
    });
  } catch (error) {
    console.error('Info error:', error);
    return c.json({ code: 500, detail: '获取信息失败' }, 500);
  }
});

// 定时清理任务
app.get('/cleanup', async (c) => {
  const result = await cleanupExpiredFiles(c.env);
  return c.json({ code: 0, data: result });
});

// 导出 Worker
export default {
  fetch: app.fetch,
  
  // 定时任务处理器
  scheduled: async (event, env, ctx) => {
    console.log('🕐 Scheduled cleanup triggered');
    ctx.waitUntil(cleanupExpiredFiles(env));
  },
};