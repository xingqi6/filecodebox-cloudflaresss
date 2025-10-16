# 🛠️ 手動 KV Namespace 設置指南

## 🚨 當前問題
KV namespace 創建在 GitHub Actions 中失敗，但沒有顯示具體錯誤信息。

## 🎯 立即解決方案

### 步驟 1：本地調試
```bash
# 設置 API token
export CLOUDFLARE_API_TOKEN=your_token_here

# 運行調試腳本
./debug-kv-creation.sh
```

### 步驟 2：手動創建 KV Namespaces

如果調試腳本顯示權限問題，請按以下步驟操作：

#### A. 檢查 API Token 權限
1. 前往：https://dash.cloudflare.com/profile/api-tokens
2. 找到您的 API token
3. 確保有以下權限：
   - ✅ `Account: Cloudflare Workers:Edit`
   - ✅ `Account: Account Settings:Read`

#### B. 重新創建 API Token（如果權限不足）
1. 刪除舊的 token
2. 創建新的 "Custom token"
3. 設置權限：
   - Account → `Cloudflare Workers:Edit`
   - Account → `Account Settings:Read`
4. 複製新的 token

#### C. 手動創建 KV Namespaces
```bash
# 設置新的 API token
export CLOUDFLARE_API_TOKEN=new_token_here

# 可選：設置 Account ID
export CLOUDFLARE_ACCOUNT_ID=your_account_id

# 創建主 KV namespace
npx wrangler kv namespace create filecodebox-kv-2c88c777

# 創建預覽 KV namespace
npx wrangler kv namespace create filecodebox-kv-2c88c777-preview --preview
```

#### D. 更新 wrangler.toml
將返回的 ID 手動替換到 `wrangler.toml` 中：

```toml
[[kv_namespaces]]
binding = "FILECODEBOX_KV"
id = "替換為主 KV namespace ID"
preview_id = "替換為預覽 KV namespace ID"
```

### 步驟 3：部署
```bash
# 部署到 Cloudflare Workers
npx wrangler deploy
```

## 🔍 常見問題和解決方案

### 問題 1：權限不足
**錯誤**：Permission denied 或 Unauthorized
**解決**：重新創建 API token 並確保有正確權限

### 問題 2：配額限制
**錯誤**：Quota exceeded 或 Limit reached
**解決**：
- 免費帳戶只能創建 1 個 KV namespace
- 刪除未使用的 KV namespaces：
  ```bash
  npx wrangler kv namespace list
  npx wrangler kv namespace delete --namespace-id <unused_id>
  ```

### 問題 3：Account ID 問題
**錯誤**：Account related errors
**解決**：
```bash
# 獲取 Account ID
npx wrangler whoami

# 設置環境變數
export CLOUDFLARE_ACCOUNT_ID=your_account_id_here
```

### 問題 4：網絡問題
**錯誤**：Network timeout 或 Connection failed
**解決**：
- 檢查網絡連接
- 嘗試使用 VPN
- 稍後重試

## 🚀 快速成功路徑

如果您想快速解決問題：

1. **運行調試腳本**：
   ```bash
   export CLOUDFLARE_API_TOKEN=your_token
   ./debug-kv-creation.sh
   ```

2. **根據輸出結果**：
   - 如果成功 → 運行 `./deploy-local.sh`
   - 如果權限問題 → 重新創建 API token
   - 如果配額問題 → 刪除未使用的 namespaces

3. **更新 GitHub Secrets**（如果重新創建了 token）：
   - `CLOUDFLARE_API_TOKEN`: 新的 token
   - `CLOUDFLARE_ACCOUNT_ID`: 您的 Account ID

## 📞 需要幫助？

如果問題仍然存在：

1. **運行調試腳本** 並分享輸出結果
2. **檢查 Cloudflare 狀態**：https://www.cloudflarestatus.com/
3. **查看 API 文檔**：https://developers.cloudflare.com/api/

## ✅ 成功標誌

當您看到以下輸出時，說明設置成功：

```
✨ Success! Add the following to your configuration file in your kv_namespaces array:
{ binding = "KV", id = "abc123def456..." }
```

然後您就可以正常使用 FileCodeBox 了！