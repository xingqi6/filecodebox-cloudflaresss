#!/bin/bash

# Cloudflare 連接測試腳本
# 用於診斷 KV namespace 創建問題

echo "🔍 Cloudflare 連接診斷腳本"
echo "=========================="

# 檢查環境變數
echo ""
echo "📋 環境變數檢查："
echo "- CLOUDFLARE_API_TOKEN: $([ -n "$CLOUDFLARE_API_TOKEN" ] && echo "已設置 (${#CLOUDFLARE_API_TOKEN} 字符)" || echo "未設置")"
echo "- CLOUDFLARE_ACCOUNT_ID: $([ -n "$CLOUDFLARE_ACCOUNT_ID" ] && echo "已設置 (${#CLOUDFLARE_ACCOUNT_ID} 字符)" || echo "未設置")"

# 檢查 wrangler 版本
echo ""
echo "🛠️  工具版本："
echo "- Node.js: $(node --version 2>/dev/null || echo "未安裝")"
echo "- npm: $(npm --version 2>/dev/null || echo "未安裝")"
echo "- wrangler: $(npx wrangler --version 2>/dev/null || echo "未安裝")"

# 測試認證
echo ""
echo "🔐 測試 Cloudflare 認證..."

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN 未設置"
    echo ""
    echo "請設置 API token："
    echo "export CLOUDFLARE_API_TOKEN=your_token_here"
    exit 1
fi

WHOAMI_OUTPUT=$(npx wrangler whoami 2>&1)
WHOAMI_EXIT_CODE=$?

echo "認證測試結果："
echo "- 退出代碼: $WHOAMI_EXIT_CODE"
echo "- 輸出: $WHOAMI_OUTPUT"

if [ $WHOAMI_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "❌ 認證失敗！可能的原因："
    echo "1. API token 無效或過期"
    echo "2. API token 權限不足"
    echo "3. 網絡連接問題"
    echo "4. Cloudflare 服務異常"
    exit 1
fi

echo "✅ 認證成功"

# 測試 KV namespace 列表
echo ""
echo "📋 測試 KV namespace 列表..."

KV_LIST_OUTPUT=$(npx wrangler kv namespace list 2>&1)
KV_LIST_EXIT_CODE=$?

echo "KV 列表測試結果："
echo "- 退出代碼: $KV_LIST_EXIT_CODE"
echo "- 輸出: $KV_LIST_OUTPUT"

if [ $KV_LIST_EXIT_CODE -ne 0 ]; then
    echo "❌ 無法列出 KV namespaces"
else
    echo "✅ KV namespace 列表獲取成功"
fi

# 測試 R2 bucket 列表
echo ""
echo "🪣 測試 R2 bucket 列表..."

R2_LIST_OUTPUT=$(npx wrangler r2 bucket list 2>&1)
R2_LIST_EXIT_CODE=$?

echo "R2 列表測試結果："
echo "- 退出代碼: $R2_LIST_EXIT_CODE"
echo "- 輸出: $R2_LIST_OUTPUT"

if [ $R2_LIST_EXIT_CODE -ne 0 ]; then
    echo "❌ 無法列出 R2 buckets"
else
    echo "✅ R2 bucket 列表獲取成功"
fi

# 嘗試創建測試 KV namespace
echo ""
echo "🧪 測試創建 KV namespace..."

TEST_KV_NAME="test-kv-$(date +%s)"
echo "測試 KV namespace 名稱: $TEST_KV_NAME"

TEST_KV_OUTPUT=$(npx wrangler kv namespace create "$TEST_KV_NAME" 2>&1)
TEST_KV_EXIT_CODE=$?

echo "測試 KV 創建結果："
echo "- 退出代碼: $TEST_KV_EXIT_CODE"
echo "- 輸出: $TEST_KV_OUTPUT"

if [ $TEST_KV_EXIT_CODE -eq 0 ]; then
    echo "✅ 測試 KV namespace 創建成功"
    
    # 提取 ID 並刪除測試 namespace
    TEST_KV_ID=$(echo "$TEST_KV_OUTPUT" | grep -o 'id = "[^"]*"' | sed 's/id = "\(.*\)"/\1/')
    if [ -n "$TEST_KV_ID" ]; then
        echo "📋 測試 KV ID: $TEST_KV_ID"
        echo "🗑️  清理測試 KV namespace..."
        npx wrangler kv namespace delete --namespace-id "$TEST_KV_ID" --force 2>/dev/null || echo "清理失敗（這是正常的）"
    fi
else
    echo "❌ 測試 KV namespace 創建失敗"
    echo ""
    echo "🔍 詳細錯誤分析："
    
    if echo "$TEST_KV_OUTPUT" | grep -q "permission"; then
        echo "- 權限問題：API token 可能沒有 'Cloudflare Workers:Edit' 權限"
    elif echo "$TEST_KV_OUTPUT" | grep -q "authentication"; then
        echo "- 認證問題：API token 可能無效"
    elif echo "$TEST_KV_OUTPUT" | grep -q "account"; then
        echo "- 帳戶問題：可能需要設置 CLOUDFLARE_ACCOUNT_ID"
    elif echo "$TEST_KV_OUTPUT" | grep -q "network\|timeout"; then
        echo "- 網絡問題：連接 Cloudflare API 失敗"
    else
        echo "- 未知錯誤：請檢查完整的錯誤輸出"
    fi
fi

echo ""
echo "📊 診斷總結："
echo "============="

if [ $WHOAMI_EXIT_CODE -eq 0 ] && [ $KV_LIST_EXIT_CODE -eq 0 ] && [ $TEST_KV_EXIT_CODE -eq 0 ]; then
    echo "🎉 所有測試通過！Cloudflare 連接正常"
    echo "可以嘗試運行完整的部署腳本：./deploy-local.sh"
elif [ $WHOAMI_EXIT_CODE -eq 0 ] && [ $KV_LIST_EXIT_CODE -eq 0 ]; then
    echo "⚠️  基本連接正常，但 KV 創建有問題"
    echo "建議檢查 API token 的具體權限設置"
elif [ $WHOAMI_EXIT_CODE -eq 0 ]; then
    echo "⚠️  認證成功，但部分功能有問題"
    echo "可能是權限或帳戶配置問題"
else
    echo "❌ 基本認證失敗"
    echo "請檢查 API token 是否正確設置"
fi

echo ""
echo "🔧 建議的下一步："
if [ $WHOAMI_EXIT_CODE -ne 0 ]; then
    echo "1. 檢查並重新生成 API token"
    echo "2. 確保 token 有正確的權限"
    echo "3. 檢查網絡連接"
else
    echo "1. 如果是權限問題，重新創建 API token 並確保有 'Cloudflare Workers:Edit' 權限"
    echo "2. 如果是帳戶問題，設置 CLOUDFLARE_ACCOUNT_ID 環境變數"
    echo "3. 嘗試運行 ./deploy-local.sh 進行完整部署"
fi
