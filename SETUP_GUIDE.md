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
