# Cloudflare Workers 設置指南

## 🔑 API Token 設置

為了完成 R2 buckets 和 KV namespaces 的創建，您需要設置 Cloudflare API token。

### 步驟 1：創建 API Token

1. 前往 [Cloudflare API Tokens 頁面](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
2. 點擊 "Create Token"
3. 選擇 "Custom token" 模板
4. 設置以下權限：
   - **Zone:Zone:Read** - 讀取區域信息
   - **Zone:Zone Settings:Edit** - 編輯區域設置
   - **Account:Cloudflare Workers:Edit** - 管理 Workers
   - **Account:Account Settings:Read** - 讀取帳戶設置

### 步驟 2：設置環境變數

```bash
export CLOUDFLARE_API_TOKEN=your_token_here
```

### 步驟 3：完成設置

執行以下命令完成 KV namespaces 創建：

```bash
./setup-kv-namespaces.sh
```

## 📋 當前狀態

### ✅ 已完成
- R2 buckets 創建命令已執行
  - 主要 bucket: `filecodebox-r2-f6bd1dfe`
  - 預覽 bucket: `filecodebox-r2-f6bd1dfe-preview`

### ⏳ 待完成
- KV namespaces 創建（需要 API token）
  - 主要 namespace: `filecodebox-kv-2c88c777`
  - 預覽 namespace: `filecodebox-kv-2c88c777-preview`

## 🔧 故障排除

### 錯誤：wrangler: command not found
- 使用 `npx wrangler` 而不是 `wrangler`

### 錯誤：API token required
- 確保已設置 `CLOUDFLARE_API_TOKEN` 環境變數
- 檢查 token 權限是否正確

### 錯誤：Bucket already exists
- 這是正常的，buckets 可能已經存在
- 繼續執行後續步驟即可

## 📁 文件結構

```
/workspace/
├── src/
│   └── index.js          # Worker 主程式
├── wrangler.toml         # Cloudflare Workers 配置
├── setup-kv-namespaces.sh  # KV 設置腳本
└── CLOUDFLARE_SETUP.md   # 本說明文件
```

## 🚀 下一步

1. 設置 API token
2. 執行 KV namespaces 創建腳本
3. 部署 Worker: `npx wrangler deploy`
4. 測試應用功能