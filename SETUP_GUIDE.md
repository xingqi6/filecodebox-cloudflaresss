# FileCodeBox 設置指南

## 🚀 快速開始

### 方法一：自動部署（推薦）

1. **配置 GitHub Secrets**
   - 前往你的 GitHub 倉庫 Settings > Secrets and variables > Actions
   - 添加以下 secrets：
     - `CLOUDFLARE_API_TOKEN`: 你的 Cloudflare API token
     - `CLOUDFLARE_ACCOUNT_ID`: 你的 Cloudflare Account ID

2. **觸發部署**
   - 推送代碼到 main/master 分支，或
   - 在 Actions 頁面手動觸發 workflow

### 方法二：手動設置

如果自動部署失敗，可以手動完成設置：

```bash
# 1. 設置環境變數
export CLOUDFLARE_API_TOKEN=your_token_here

# 2. 安裝依賴
npm install

# 3. 創建 KV namespaces
npx wrangler kv namespace create filecodebox-kv-2c88c777
npx wrangler kv namespace create filecodebox-kv-2c88c777-preview --preview

# 4. 更新 wrangler.toml
# 將返回的 ID 替換 PLACEHOLDER_KV_ID 和 PLACEHOLDER_KV_PREVIEW_ID

# 5. 部署
npx wrangler deploy
```

## 🔑 獲取 Cloudflare 憑證

### API Token
1. 前往 [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. 點擊 "Create Token"
3. 使用 "Custom token" 模板
4. 設置權限：
   - **Account** - `Cloudflare Workers:Edit`
   - **Zone** - `Zone:Read` (如果有自定義域名)
   - **Zone** - `Zone Settings:Edit` (如果有自定義域名)

### Account ID
1. 登錄 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 在右側邊欄找到 "Account ID"

## 📋 驗證部署

部署成功後：

1. **檢查 Worker**
   - 前往 Cloudflare Dashboard > Workers & Pages
   - 找到 `filecodebox` Worker
   - 點擊查看部署狀態

2. **測試功能**
   - 訪問 Worker URL
   - 嘗試上傳文件或文本
   - 使用取件碼下載

## 🔧 故障排除

### 常見問題

**1. KV Namespace 創建失敗**
```
Error: Unknown argument: json
```
- 確保使用正確的 wrangler 版本
- 檢查 API token 權限

**2. 部署失敗**
```
Build failed with 1 error: Unexpected external import
```
- 檢查 Worker 代碼是否有正確的 `export default`

**3. API Token 權限不足**
```
You do not have permission to perform this action
```
- 確保 API token 有 `Cloudflare Workers:Edit` 權限

### 手動檢查命令

```bash
# 檢查認證
npx wrangler whoami

# 列出 KV namespaces
npx wrangler kv namespace list

# 列出 R2 buckets
npx wrangler r2 bucket list

# 檢查配置
npx wrangler deploy --dry-run
```

## 📞 獲取幫助

如果遇到問題：

1. 檢查 [Cloudflare Workers 文檔](https://developers.cloudflare.com/workers/)
2. 查看 GitHub Actions 日誌
3. 確認所有 secrets 都已正確設置
4. 嘗試手動執行命令以獲取更詳細的錯誤信息

## 🎉 完成！

設置完成後，你的 FileCodeBox 就可以使用了！

- 📤 上傳文件或文本
- 🔢 獲取 6 位取件碼  
- 📥 使用取件碼下載
- ⏰ 自動過期清理