# 手動 KV Namespace 設置指南

如果自動腳本無法正常工作，請按照以下步驟手動創建 KV namespaces。

## 🔑 前提條件

1. 確保已設置 Cloudflare API Token：
   ```bash
   export CLOUDFLARE_API_TOKEN=your_token_here
   ```

2. 測試連接：
   ```bash
   npx wrangler whoami
   ```

## 📝 手動創建步驟

### 步驟 1：創建主要 KV Namespace

```bash
npx wrangler kv namespace create filecodebox-kv-2c88c777
```

**預期輸出示例：**
```
🌀 Creating namespace with title "filecodebox-kv-2c88c777"
✨ Success! Add the following to your configuration file in your kv_namespaces array:
{ binding = "KV", id = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz" }
```

### 步驟 2：創建預覽 KV Namespace

```bash
npx wrangler kv namespace create filecodebox-kv-2c88c777-preview --preview
```

**預期輸出示例：**
```
🌀 Creating namespace with title "filecodebox-kv-2c88c777-preview"
✨ Success! Add the following to your configuration file in your kv_namespaces array:
{ binding = "KV", preview_id = "def456ghi789jkl012mno345pqr678stu901vwx234yz567abc" }
```

### 步驟 3：更新 wrangler.toml

將 `wrangler.toml` 中的佔位符替換為實際的 namespace ID：

**修改前：**
```toml
[[kv_namespaces]]
binding = "FILECODEBOX_KV"
id = "PLACEHOLDER_KV_ID"
preview_id = "PLACEHOLDER_KV_PREVIEW_ID"
```

**修改後：**
```toml
[[kv_namespaces]]
binding = "FILECODEBOX_KV"
id = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
preview_id = "def456ghi789jkl012mno345pqr678stu901vwx234yz567abc"
```

## 🔧 故障排除

### 問題 1：API Token 錯誤
```
✘ [ERROR] In a non-interactive environment, it's necessary to set a CLOUDFLARE_API_TOKEN
```

**解決方案：**
- 確保設置了正確的環境變數
- 檢查 API token 權限是否包含 Workers 管理權限

### 問題 2：Namespace 已存在
```
✘ [ERROR] A namespace with this name already exists
```

**解決方案：**
- 使用不同的名稱，或者
- 列出現有的 namespaces：`npx wrangler kv namespace list`
- 使用現有的 namespace ID

### 問題 3：權限不足
```
✘ [ERROR] You do not have permission to perform this action
```

**解決方案：**
- 檢查 API token 權限
- 確保 token 有 `Account:Cloudflare Workers:Edit` 權限

## 📋 驗證設置

創建完成後，驗證配置：

```bash
# 檢查配置文件
cat wrangler.toml

# 列出所有 KV namespaces
npx wrangler kv namespace list

# 測試部署（不會實際部署，只檢查配置）
npx wrangler deploy --dry-run
```

## 🚀 完成後的下一步

1. **部署 Worker：**
   ```bash
   npx wrangler deploy
   ```

2. **測試 KV 存儲：**
   ```bash
   # 寫入測試數據
   npx wrangler kv key put "test-key" "test-value" --binding FILECODEBOX_KV
   
   # 讀取測試數據
   npx wrangler kv key get "test-key" --binding FILECODEBOX_KV
   ```

3. **檢查 Worker 日誌：**
   ```bash
   npx wrangler tail
   ```