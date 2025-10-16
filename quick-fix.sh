#!/bin/bash

# FileCodeBox 快速修復腳本
# 用於解決 KV namespace 創建失敗的問題

set -e

echo "🔧 FileCodeBox 快速修復腳本"
echo "================================="

# 檢查是否設置了 API token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo ""
    echo "❌ 未找到 CLOUDFLARE_API_TOKEN 環境變數"
    echo ""
    echo "請選擇以下選項之一："
    echo "1. 設置環境變數並重新運行此腳本"
    echo "2. 手動輸入 API token（不推薦）"
    echo "3. 退出並使用 GitHub Secrets 配置"
    echo ""
    read -p "請選擇 (1/2/3): " choice
    
    case $choice in
        1)
            echo ""
            echo "請運行以下命令設置環境變數："
            echo "export CLOUDFLARE_API_TOKEN=your_token_here"
            echo "然後重新運行此腳本：./quick-fix.sh"
            exit 0
            ;;
        2)
            echo ""
            read -p "請輸入您的 Cloudflare API Token: " -s token
            echo ""
            if [ -z "$token" ]; then
                echo "❌ 未提供 token，退出"
                exit 1
            fi
            export CLOUDFLARE_API_TOKEN="$token"
            echo "✅ 已設置臨時 API token"
            ;;
        3)
            echo ""
            echo "📋 GitHub Secrets 配置步驟："
            echo "1. 前往 GitHub 倉庫 Settings > Secrets and variables > Actions"
            echo "2. 添加 CLOUDFLARE_API_TOKEN secret"
            echo "3. 添加 CLOUDFLARE_ACCOUNT_ID secret"
            echo "4. 重新運行 GitHub Action"
            exit 0
            ;;
        *)
            echo "❌ 無效選擇，退出"
            exit 1
            ;;
    esac
fi

echo ""
echo "🔍 測試 Cloudflare 連接..."

# 測試 wrangler 連接
if ! npx wrangler whoami > /dev/null 2>&1; then
    echo "❌ Cloudflare API 連接失敗"
    echo "請檢查："
    echo "1. API token 是否正確"
    echo "2. 網絡連接是否正常"
    echo "3. API token 是否有正確的權限"
    exit 1
fi

echo "✅ Cloudflare 連接成功"

echo ""
echo "🗄️ 創建 KV namespaces..."

# 創建主 KV namespace
echo "創建主 KV namespace: filecodebox-kv-2c88c777"
MAIN_OUTPUT=$(npx wrangler kv namespace create filecodebox-kv-2c88c777 2>&1)
MAIN_EXIT_CODE=$?

if [ $MAIN_EXIT_CODE -eq 0 ]; then
    echo "✅ 主 KV namespace 創建成功"
    echo "$MAIN_OUTPUT"
    
    # 提取 ID
    MAIN_KV_ID=$(echo "$MAIN_OUTPUT" | grep -o 'id = "[^"]*"' | sed 's/id = "\(.*\)"/\1/')
    
    if [ -z "$MAIN_KV_ID" ]; then
        echo "⚠️  無法提取主 KV ID，請手動複製"
        echo "輸出: $MAIN_OUTPUT"
    else
        echo "📋 主 KV ID: $MAIN_KV_ID"
    fi
else
    echo "❌ 主 KV namespace 創建失敗"
    echo "$MAIN_OUTPUT"
    
    # 嘗試列出現有的 namespaces
    echo ""
    echo "🔍 檢查現有的 KV namespaces..."
    EXISTING_KV=$(npx wrangler kv namespace list --json 2>/dev/null || echo "[]")
    MAIN_KV_ID=$(echo "$EXISTING_KV" | jq -r '.[] | select(.title == "filecodebox-kv-2c88c777") | .id' 2>/dev/null | head -1)
    
    if [ -n "$MAIN_KV_ID" ] && [ "$MAIN_KV_ID" != "null" ]; then
        echo "✅ 找到現有的主 KV namespace: $MAIN_KV_ID"
    else
        echo "❌ 無法找到或創建主 KV namespace"
        exit 1
    fi
fi

echo ""
echo "創建預覽 KV namespace: filecodebox-kv-2c88c777-preview"
PREVIEW_OUTPUT=$(npx wrangler kv namespace create filecodebox-kv-2c88c777-preview --preview 2>&1)
PREVIEW_EXIT_CODE=$?

if [ $PREVIEW_EXIT_CODE -eq 0 ]; then
    echo "✅ 預覽 KV namespace 創建成功"
    echo "$PREVIEW_OUTPUT"
    
    # 提取預覽 ID
    PREVIEW_KV_ID=$(echo "$PREVIEW_OUTPUT" | grep -o 'preview_id = "[^"]*"' | sed 's/preview_id = "\(.*\)"/\1/')
    
    if [ -z "$PREVIEW_KV_ID" ]; then
        echo "⚠️  無法提取預覽 KV ID，使用主 KV ID"
        PREVIEW_KV_ID="$MAIN_KV_ID"
    else
        echo "📋 預覽 KV ID: $PREVIEW_KV_ID"
    fi
else
    echo "❌ 預覽 KV namespace 創建失敗"
    echo "$PREVIEW_OUTPUT"
    
    # 使用主 KV ID 作為預覽 ID
    PREVIEW_KV_ID="$MAIN_KV_ID"
    echo "ℹ️  使用主 KV ID 作為預覽 ID: $PREVIEW_KV_ID"
fi

echo ""
echo "📝 更新 wrangler.toml..."

if [ -n "$MAIN_KV_ID" ] && [ -n "$PREVIEW_KV_ID" ]; then
    # 備份原文件
    cp wrangler.toml wrangler.toml.backup
    echo "📋 已備份 wrangler.toml 為 wrangler.toml.backup"
    
    # 更新配置
    sed -i "s/PLACEHOLDER_KV_ID/$MAIN_KV_ID/g" wrangler.toml
    sed -i "s/PLACEHOLDER_KV_PREVIEW_ID/$PREVIEW_KV_ID/g" wrangler.toml
    
    echo "✅ wrangler.toml 已更新"
    
    # 顯示更新後的配置
    echo ""
    echo "📄 更新後的 KV 配置："
    grep -A 3 "kv_namespaces" wrangler.toml
else
    echo "❌ 無法更新 wrangler.toml - 缺少 KV ID"
    echo "請手動更新以下配置："
    echo "主 KV ID: $MAIN_KV_ID"
    echo "預覽 KV ID: $PREVIEW_KV_ID"
    exit 1
fi

echo ""
echo "🚀 嘗試部署..."

if npx wrangler deploy; then
    echo ""
    echo "🎉 部署成功！"
    echo ""
    echo "📋 部署信息："
    echo "- 主 KV ID: $MAIN_KV_ID"
    echo "- 預覽 KV ID: $PREVIEW_KV_ID"
    echo "- Worker 名稱: filecodebox"
    echo ""
    echo "🌐 請前往 Cloudflare Workers Dashboard 查看部署 URL"
else
    echo ""
    echo "⚠️  部署失敗，但 KV namespaces 已創建並配置"
    echo "請檢查錯誤信息並手動部署："
    echo "npx wrangler deploy"
fi

echo ""
echo "✅ 快速修復完成！"