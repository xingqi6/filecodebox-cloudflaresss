#!/bin/bash

# FileCodeBox 本地部署腳本
# 繞過 GitHub Actions，直接本地部署

echo "🚀 FileCodeBox 本地部署腳本"
echo "============================="

# 檢查 Node.js
if ! command -v node &> /dev/null; then
    echo "❌ 需要安裝 Node.js"
    echo "請前往 https://nodejs.org 下載安裝"
    exit 1
fi

echo "✅ Node.js 版本: $(node --version)"

# 檢查 npm
if ! command -v npm &> /dev/null; then
    echo "❌ 需要安裝 npm"
    exit 1
fi

echo "✅ npm 版本: $(npm --version)"

# 檢查 API token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo ""
    echo "❌ 未設置 CLOUDFLARE_API_TOKEN 環境變數"
    echo ""
    echo "請按照以下步驟獲取並設置 API token："
    echo ""
    echo "1. 前往 https://dash.cloudflare.com/profile/api-tokens"
    echo "2. 點擊 'Create Token'"
    echo "3. 選擇 'Custom token'"
    echo "4. 設置權限："
    echo "   - Account: Cloudflare Workers:Edit"
    echo "   - Account: Account Settings:Read"
    echo "5. 創建並複製 token"
    echo ""
    echo "然後運行："
    echo "export CLOUDFLARE_API_TOKEN=your_token_here"
    echo "./deploy-local.sh"
    echo ""
    exit 1
fi

echo "✅ 找到 Cloudflare API token"

# 測試 Cloudflare 連接
echo ""
echo "🔍 測試 Cloudflare 連接..."

if ! npx wrangler whoami > /dev/null 2>&1; then
    echo "❌ Cloudflare 連接失敗"
    echo "請檢查 API token 是否正確"
    exit 1
fi

echo "✅ Cloudflare 連接成功"

# 安裝依賴
echo ""
echo "📦 安裝依賴..."
if ! npm install; then
    echo "❌ 依賴安裝失敗"
    exit 1
fi

echo "✅ 依賴安裝完成"

# 創建 R2 buckets
echo ""
echo "🪣 創建 R2 buckets..."

echo "創建主 bucket: filecodebox-r2-f6bd1dfe"
if npx wrangler r2 bucket create "filecodebox-r2-f6bd1dfe" 2>/dev/null; then
    echo "✅ 主 bucket 創建成功"
else
    echo "ℹ️  主 bucket 可能已存在"
fi

echo "創建預覽 bucket: filecodebox-r2-f6bd1dfe-preview"
if npx wrangler r2 bucket create "filecodebox-r2-f6bd1dfe-preview" 2>/dev/null; then
    echo "✅ 預覽 bucket 創建成功"
else
    echo "ℹ️  預覽 bucket 可能已存在"
fi

# 創建 KV namespaces
echo ""
echo "🗄️ 創建 KV namespaces..."

echo "創建主 KV namespace: filecodebox-kv-2c88c777"
MAIN_KV_OUTPUT=$(npx wrangler kv namespace create "filecodebox-kv-2c88c777" 2>&1)
MAIN_KV_EXIT_CODE=$?

if [ $MAIN_KV_EXIT_CODE -eq 0 ]; then
    echo "✅ 主 KV namespace 創建成功"
    MAIN_KV_ID=$(echo "$MAIN_KV_OUTPUT" | grep -o 'id = "[^"]*"' | sed 's/id = "\(.*\)"/\1/')
    echo "📋 主 KV ID: $MAIN_KV_ID"
else
    echo "ℹ️  主 KV namespace 創建失敗，檢查現有的..."
    
    # 檢查現有的 KV namespaces
    KV_LIST=$(npx wrangler kv namespace list --json 2>/dev/null || echo "[]")
    MAIN_KV_ID=$(echo "$KV_LIST" | jq -r '.[] | select(.title == "filecodebox-kv-2c88c777") | .id' 2>/dev/null | head -1)
    
    if [ -n "$MAIN_KV_ID" ] && [ "$MAIN_KV_ID" != "null" ]; then
        echo "✅ 找到現有主 KV namespace: $MAIN_KV_ID"
    else
        echo "❌ 無法創建或找到主 KV namespace"
        echo "錯誤: $MAIN_KV_OUTPUT"
        exit 1
    fi
fi

echo "創建預覽 KV namespace: filecodebox-kv-2c88c777-preview"
PREVIEW_KV_OUTPUT=$(npx wrangler kv namespace create "filecodebox-kv-2c88c777-preview" --preview 2>&1)
PREVIEW_KV_EXIT_CODE=$?

if [ $PREVIEW_KV_EXIT_CODE -eq 0 ]; then
    echo "✅ 預覽 KV namespace 創建成功"
    PREVIEW_KV_ID=$(echo "$PREVIEW_KV_OUTPUT" | grep -o 'preview_id = "[^"]*"' | sed 's/preview_id = "\(.*\)"/\1/')
    echo "📋 預覽 KV ID: $PREVIEW_KV_ID"
else
    echo "ℹ️  預覽 KV namespace 創建失敗，使用主 KV ID"
    PREVIEW_KV_ID="$MAIN_KV_ID"
    echo "📋 預覽 KV ID: $PREVIEW_KV_ID"
fi

# 更新 wrangler.toml
echo ""
echo "📝 更新 wrangler.toml..."

if [ -n "$MAIN_KV_ID" ] && [ -n "$PREVIEW_KV_ID" ]; then
    # 備份原文件
    cp wrangler.toml wrangler.toml.backup.$(date +%Y%m%d_%H%M%S)
    echo "📋 已備份 wrangler.toml"
    
    # 更新配置
    sed -i.bak "s/PLACEHOLDER_KV_ID/$MAIN_KV_ID/g" wrangler.toml
    sed -i.bak "s/PLACEHOLDER_KV_PREVIEW_ID/$PREVIEW_KV_ID/g" wrangler.toml
    
    # 刪除備份文件（macOS 兼容性）
    rm -f wrangler.toml.bak
    
    echo "✅ wrangler.toml 更新完成"
    
    # 顯示更新後的配置
    echo ""
    echo "📄 更新後的 KV 配置："
    grep -A 3 "kv_namespaces" wrangler.toml
else
    echo "❌ 無法更新 wrangler.toml - 缺少 KV ID"
    exit 1
fi

# 部署
echo ""
echo "🚀 部署到 Cloudflare Workers..."

if npx wrangler deploy; then
    echo ""
    echo "🎉 部署成功！"
    echo ""
    echo "📋 部署信息："
    echo "- Worker 名稱: filecodebox"
    echo "- 主 KV ID: $MAIN_KV_ID"
    echo "- 預覽 KV ID: $PREVIEW_KV_ID"
    echo "- R2 Bucket: filecodebox-r2-f6bd1dfe"
    echo ""
    echo "🌐 請前往 Cloudflare Workers Dashboard 查看部署 URL："
    echo "https://dash.cloudflare.com/workers"
    echo ""
    echo "✅ FileCodeBox 部署完成！現在可以使用文件快傳功能了。"
else
    echo ""
    echo "❌ 部署失敗"
    echo "請檢查錯誤信息並重試"
    exit 1
fi
