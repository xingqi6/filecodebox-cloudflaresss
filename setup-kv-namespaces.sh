#!/bin/bash

# 設置 KV Namespaces 的腳本
# 需要先設置 CLOUDFLARE_API_TOKEN 環境變數

echo "🗄️ 設置 KV namespaces..."

# 檢查是否設置了 API token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ 錯誤：需要設置 CLOUDFLARE_API_TOKEN 環境變數"
    echo ""
    echo "請按照以下步驟操作："
    echo "1. 前往 https://developers.cloudflare.com/fundamentals/api/get-started/create-token/"
    echo "2. 創建一個具有以下權限的 API token："
    echo "   - Zone:Zone:Read"
    echo "   - Zone:Zone Settings:Edit"  
    echo "   - Account:Cloudflare Workers:Edit"
    echo "   - Account:Account Settings:Read"
    echo "3. 設置環境變數：export CLOUDFLARE_API_TOKEN=your_token_here"
    echo "4. 重新執行此腳本"
    echo ""
    exit 1
fi

echo "✅ 找到 API token，開始創建 KV namespaces..."

# 創建主要 KV namespace
echo "創建主要 KV namespace: filecodebox-kv-2c88c777"
MAIN_KV_OUTPUT=$(npx wrangler kv namespace create "filecodebox-kv-2c88c777" 2>&1)
echo "$MAIN_KV_OUTPUT"

# 從輸出中提取 namespace ID
MAIN_KV_ID=$(echo "$MAIN_KV_OUTPUT" | grep -o 'id = "[^"]*"' | head -1 | sed 's/id = "\(.*\)"/\1/')

# 創建預覽 KV namespace  
echo "創建預覽 KV namespace: filecodebox-kv-2c88c777-preview"
PREVIEW_KV_OUTPUT=$(npx wrangler kv namespace create "filecodebox-kv-2c88c777" --preview 2>&1)
echo "$PREVIEW_KV_OUTPUT"

# 從輸出中提取預覽 namespace ID
PREVIEW_KV_ID=$(echo "$PREVIEW_KV_OUTPUT" | grep -o 'preview_id = "[^"]*"' | head -1 | sed 's/preview_id = "\(.*\)"/\1/')

echo ""
echo "📝 請更新 wrangler.toml 文件中的以下配置："
echo "將 PLACEHOLDER_KV_ID 替換為: $MAIN_KV_ID"
echo "將 PLACEHOLDER_KV_PREVIEW_ID 替換為: $PREVIEW_KV_ID"
echo ""

# 如果成功獲取到 ID，自動更新 wrangler.toml
if [ ! -z "$MAIN_KV_ID" ] && [ ! -z "$PREVIEW_KV_ID" ]; then
    echo "🔄 自動更新 wrangler.toml..."
    sed -i "s/PLACEHOLDER_KV_ID/$MAIN_KV_ID/g" wrangler.toml
    sed -i "s/PLACEHOLDER_KV_PREVIEW_ID/$PREVIEW_KV_ID/g" wrangler.toml
    echo "✅ wrangler.toml 已更新完成！"
else
    echo "⚠️  無法自動更新 wrangler.toml，請手動替換 ID"
fi

echo ""
echo "🎉 KV namespaces 設置完成！"