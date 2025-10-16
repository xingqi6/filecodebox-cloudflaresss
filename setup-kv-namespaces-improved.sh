#!/bin/bash

# 改進的 KV Namespaces 設置腳本
# 支持手動輸入 API token 或使用環境變數

echo "🗄️ 設置 KV namespaces..."

# 檢查是否設置了 API token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ 未找到 CLOUDFLARE_API_TOKEN 環境變數"
    echo ""
    echo "請選擇以下選項之一："
    echo "1. 設置環境變數後重新執行："
    echo "   export CLOUDFLARE_API_TOKEN=your_token_here"
    echo "   ./setup-kv-namespaces-improved.sh"
    echo ""
    echo "2. 手動輸入 API token (不推薦，因為會在命令歷史中留下記錄)："
    read -p "請輸入您的 Cloudflare API Token (或按 Ctrl+C 退出): " -s USER_TOKEN
    echo ""
    
    if [ -z "$USER_TOKEN" ]; then
        echo "❌ 未提供 API token，退出"
        exit 1
    fi
    
    export CLOUDFLARE_API_TOKEN="$USER_TOKEN"
    echo "✅ 已設置臨時 API token"
else
    echo "✅ 找到 API token 環境變數"
fi

echo ""
echo "🔧 開始創建 KV namespaces..."

# 測試 wrangler 連接
echo "測試 Cloudflare 連接..."
TEST_OUTPUT=$(npx wrangler whoami 2>&1)
if echo "$TEST_OUTPUT" | grep -q "error\|Error\|ERROR"; then
    echo "❌ Cloudflare API 連接失敗："
    echo "$TEST_OUTPUT"
    echo ""
    echo "請檢查："
    echo "1. API token 是否正確"
    echo "2. API token 是否有正確的權限"
    echo "3. 網絡連接是否正常"
    exit 1
fi

echo "✅ Cloudflare 連接成功"
echo ""

# 創建主要 KV namespace
echo "創建主要 KV namespace: filecodebox-kv-2c88c777"
MAIN_KV_OUTPUT=$(npx wrangler kv namespace create filecodebox-kv-2c88c777 2>&1)
MAIN_KV_EXIT_CODE=$?

echo "主要 KV namespace 創建輸出："
echo "$MAIN_KV_OUTPUT"
echo ""

if [ $MAIN_KV_EXIT_CODE -ne 0 ]; then
    echo "❌ 主要 KV namespace 創建失敗 (退出代碼: $MAIN_KV_EXIT_CODE)"
    exit 1
fi

# 從輸出中提取 namespace ID
MAIN_KV_ID=$(echo "$MAIN_KV_OUTPUT" | grep -o 'id = "[^"]*"' | sed 's/id = "\(.*\)"/\1/')

if [ -z "$MAIN_KV_ID" ]; then
    echo "⚠️  無法從輸出中提取主要 namespace ID"
    echo "請手動從上面的輸出中複製 ID"
else
    echo "✅ 主要 namespace ID: $MAIN_KV_ID"
fi

echo ""

# 創建預覽 KV namespace  
echo "創建預覽 KV namespace: filecodebox-kv-2c88c777-preview"
PREVIEW_KV_OUTPUT=$(npx wrangler kv namespace create filecodebox-kv-2c88c777-preview --preview 2>&1)
PREVIEW_KV_EXIT_CODE=$?

echo "預覽 KV namespace 創建輸出："
echo "$PREVIEW_KV_OUTPUT"
echo ""

if [ $PREVIEW_KV_EXIT_CODE -ne 0 ]; then
    echo "❌ 預覽 KV namespace 創建失敗 (退出代碼: $PREVIEW_KV_EXIT_CODE)"
    exit 1
fi

# 從輸出中提取預覽 namespace ID
PREVIEW_KV_ID=$(echo "$PREVIEW_KV_OUTPUT" | grep -o 'preview_id = "[^"]*"' | sed 's/preview_id = "\(.*\)"/\1/')

if [ -z "$PREVIEW_KV_ID" ]; then
    echo "⚠️  無法從輸出中提取預覽 namespace ID"
    echo "請手動從上面的輸出中複製 ID"
else
    echo "✅ 預覽 namespace ID: $PREVIEW_KV_ID"
fi

echo ""
echo "📝 wrangler.toml 更新信息："

if [ ! -z "$MAIN_KV_ID" ] && [ ! -z "$PREVIEW_KV_ID" ]; then
    echo "🔄 自動更新 wrangler.toml..."
    
    # 備份原文件
    cp wrangler.toml wrangler.toml.backup
    echo "📋 已備份原文件為 wrangler.toml.backup"
    
    # 更新配置
    sed -i "s/PLACEHOLDER_KV_ID/$MAIN_KV_ID/g" wrangler.toml
    sed -i "s/PLACEHOLDER_KV_PREVIEW_ID/$PREVIEW_KV_ID/g" wrangler.toml
    
    echo "✅ wrangler.toml 已自動更新完成！"
    
    # 顯示更新後的配置
    echo ""
    echo "📄 更新後的 KV 配置："
    grep -A 3 "kv_namespaces" wrangler.toml
else
    echo "⚠️  無法自動更新 wrangler.toml"
    echo "請手動更新以下配置："
    echo "將 PLACEHOLDER_KV_ID 替換為主要 namespace ID"
    echo "將 PLACEHOLDER_KV_PREVIEW_ID 替換為預覽 namespace ID"
fi

echo ""
echo "🎉 KV namespaces 設置完成！"
echo ""
echo "📋 下一步："
echo "1. 檢查 wrangler.toml 配置是否正確"
echo "2. 執行 'npx wrangler deploy' 部署 Worker"
echo "3. 測試應用功能"