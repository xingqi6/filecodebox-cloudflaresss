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