# 🚨 立即解決方案 - FileCodeBox KV 設置失敗

## 問題分析
KV namespace 創建失敗，通常是因為：
1. 缺少 Cloudflare API Token
2. API Token 權限不足
3. 網絡連接問題

## 🎯 立即解決方案

### 選項 1：配置 GitHub Secrets（推薦）

1. **獲取 Cloudflare API Token**：
   - 前往：https://dash.cloudflare.com/profile/api-tokens
   - 點擊 "Create Token"
   - 選擇 "Custom token"
   - 設置權限：
     - Account: `Cloudflare Workers:Edit`
     - Account: `Account Settings:Read`
     - Zone: `Zone:Read` (可選)

2. **獲取 Account ID**：
   - 登錄 Cloudflare Dashboard
   - 在右側邊欄複製 "Account ID"

3. **設置 GitHub Secrets**：
   - 前往 GitHub 倉庫 → Settings → Secrets and variables → Actions
   - 點擊 "New repository secret"
   - 添加：
     - Name: `CLOUDFLARE_API_TOKEN`, Value: 你的 API token
     - Name: `CLOUDFLARE_ACCOUNT_ID`, Value: 你的 Account ID

4. **重新運行 Workflow**：
   - 前往 Actions 頁面
   - 點擊最新的 workflow run
   - 點擊 "Re-run all jobs"

### 選項 2：本地手動設置

```bash
# 1. 設置環境變數
export CLOUDFLARE_API_TOKEN=your_api_token_here

# 2. 測試連接
npx wrangler whoami

# 3. 創建 KV namespaces
npx wrangler kv namespace create filecodebox-kv-2c88c777
# 複製返回的 ID，例如：id = "abc123..."

npx wrangler kv namespace create filecodebox-kv-2c88c777-preview --preview  
# 複製返回的 preview_id，例如：preview_id = "def456..."

# 4. 更新 wrangler.toml
# 將 PLACEHOLDER_KV_ID 替換為主 namespace ID
# 將 PLACEHOLDER_KV_PREVIEW_ID 替換為預覽 namespace ID

# 5. 部署
npx wrangler deploy
```

### 選項 3：使用臨時 KV ID（測試用）

如果只是想快速測試，可以暫時使用假的 ID：

```bash
# 替換 wrangler.toml 中的佔位符為測試 ID
sed -i 's/PLACEHOLDER_KV_ID/test-kv-id-replace-later/g' wrangler.toml
sed -i 's/PLACEHOLDER_KV_PREVIEW_ID/test-preview-id-replace-later/g' wrangler.toml

# 嘗試部署（會失敗，但可以看到其他錯誤）
npx wrangler deploy --dry-run
```

## 🔧 故障排除

### 檢查 API Token 權限
```bash
# 測試 API token
npx wrangler whoami

# 列出現有的 KV namespaces
npx wrangler kv namespace list

# 列出 R2 buckets
npx wrangler r2 bucket list
```

### 常見錯誤及解決方案

**錯誤 1**: `wrangler: command not found`
```bash
# 解決方案：使用 npx
npx wrangler --version
```

**錯誤 2**: `API token required`
```bash
# 解決方案：設置環境變數
export CLOUDFLARE_API_TOKEN=your_token_here
```

**錯誤 3**: `Permission denied`
```bash
# 解決方案：檢查 API token 權限
# 確保有 "Cloudflare Workers:Edit" 權限
```

## 📋 驗證設置

設置完成後，運行以下命令驗證：

```bash
# 1. 檢查認證
npx wrangler whoami

# 2. 檢查 KV namespaces
npx wrangler kv namespace list

# 3. 檢查配置
npx wrangler deploy --dry-run

# 4. 實際部署
npx wrangler deploy
```

## 🎉 成功標誌

如果看到以下輸出，說明設置成功：

```
✅ Successfully created namespace with ID: abc123...
✅ Successfully created preview namespace with ID: def456...
🚀 Deploying to Cloudflare Workers...
✅ Deployment completed successfully!
```

## 📞 需要幫助？

如果仍然遇到問題：

1. **檢查 Cloudflare 狀態**：https://www.cloudflarestatus.com/
2. **查看詳細錯誤**：運行命令時添加 `--verbose` 參數
3. **檢查網絡**：確保可以訪問 Cloudflare API
4. **重新生成 Token**：嘗試創建新的 API token

---

**⚡ 快速提示**：最常見的問題是 API token 權限不足。確保你的 token 有 `Cloudflare Workers:Edit` 權限！