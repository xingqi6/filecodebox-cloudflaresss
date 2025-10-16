#!/bin/bash

# API Token 權限檢查腳本
# 用於診斷 Cloudflare API token 權限問題

echo "🔐 Cloudflare API Token 權限檢查"
echo "================================"

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN 環境變數未設置"
    echo ""
    echo "請設置 API token："
    echo "export CLOUDFLARE_API_TOKEN=your_token_here"
    exit 1
fi

echo "✅ API Token 已設置 (${#CLOUDFLARE_API_TOKEN} 字符)"

# 測試基本認證
echo ""
echo "🔍 測試基本認證..."
WHOAMI_OUTPUT=$(npx wrangler whoami 2>&1)
WHOAMI_EXIT_CODE=$?

if [ $WHOAMI_EXIT_CODE -eq 0 ]; then
    echo "✅ 基本認證成功"
    echo "$WHOAMI_OUTPUT"
else
    echo "❌ 基本認證失敗"
    echo "$WHOAMI_OUTPUT"
    exit 1
fi

# 測試 Workers 權限
echo ""
echo "🏗️  測試 Workers 權限..."

# 嘗試列出現有的 Workers
WORKERS_LIST_OUTPUT=$(npx wrangler deployments list 2>&1 || echo "No deployments found")
WORKERS_LIST_EXIT_CODE=$?

echo "Workers 列表測試："
echo "- 退出代碼: $WORKERS_LIST_EXIT_CODE"
echo "- 輸出: $WORKERS_LIST_OUTPUT"

# 測試 KV 權限
echo ""
echo "🗄️  測試 KV 權限..."

KV_LIST_OUTPUT=$(npx wrangler kv namespace list 2>&1)
KV_LIST_EXIT_CODE=$?

echo "KV 列表測試："
echo "- 退出代碼: $KV_LIST_EXIT_CODE"
echo "- 輸出: $KV_LIST_OUTPUT"

if [ $KV_LIST_EXIT_CODE -eq 0 ]; then
    echo "✅ KV 讀取權限正常"
    
    # 嘗試創建測試 KV namespace
    echo ""
    echo "🧪 測試 KV 創建權限..."
    
    TEST_KV_NAME="permission-test-$(date +%s)"
    echo "創建測試 KV namespace: $TEST_KV_NAME"
    
    TEST_CREATE_OUTPUT=$(npx wrangler kv namespace create "$TEST_KV_NAME" 2>&1)
    TEST_CREATE_EXIT_CODE=$?
    
    echo "KV 創建測試："
    echo "- 退出代碼: $TEST_CREATE_EXIT_CODE"
    echo "- 輸出: $TEST_CREATE_OUTPUT"
    
    if [ $TEST_CREATE_EXIT_CODE -eq 0 ]; then
        echo "✅ KV 創建權限正常"
        
        # 提取 ID 並清理
        TEST_KV_ID=$(echo "$TEST_CREATE_OUTPUT" | grep -o 'id = "[^"]*"' | sed 's/id = "\(.*\)"/\1/')
        if [ -n "$TEST_KV_ID" ]; then
            echo "📋 測試 KV ID: $TEST_KV_ID"
            echo "🗑️  清理測試 KV namespace..."
            
            DELETE_OUTPUT=$(npx wrangler kv namespace delete --namespace-id "$TEST_KV_ID" --force 2>&1 || echo "Delete failed")
            echo "清理結果: $DELETE_OUTPUT"
        fi
    else
        echo "❌ KV 創建權限不足"
        
        # 分析錯誤類型
        if echo "$TEST_CREATE_OUTPUT" | grep -i "permission\|forbidden\|unauthorized"; then
            echo "🔍 錯誤類型: 權限不足"
            echo "💡 解決方案: API token 需要 'Cloudflare Workers:Edit' 權限"
        elif echo "$TEST_CREATE_OUTPUT" | grep -i "account"; then
            echo "🔍 錯誤類型: 帳戶相關"
            echo "💡 解決方案: 可能需要設置 CLOUDFLARE_ACCOUNT_ID"
        elif echo "$TEST_CREATE_OUTPUT" | grep -i "limit\|quota"; then
            echo "🔍 錯誤類型: 配額限制"
            echo "💡 解決方案: 刪除未使用的 KV namespaces 或升級計劃"
        fi
    fi
else
    echo "❌ KV 讀取權限不足"
fi

# 測試 R2 權限
echo ""
echo "🪣 測試 R2 權限..."

R2_LIST_OUTPUT=$(npx wrangler r2 bucket list 2>&1)
R2_LIST_EXIT_CODE=$?

echo "R2 列表測試："
echo "- 退出代碼: $R2_LIST_EXIT_CODE"
echo "- 輸出: $R2_LIST_OUTPUT"

if [ $R2_LIST_EXIT_CODE -eq 0 ]; then
    echo "✅ R2 權限正常"
else
    echo "❌ R2 權限不足"
fi

# 總結和建議
echo ""
echo "📊 權限檢查總結"
echo "==============="

if [ $KV_LIST_EXIT_CODE -eq 0 ] && [ $TEST_CREATE_EXIT_CODE -eq 0 ] && [ $R2_LIST_EXIT_CODE -eq 0 ]; then
    echo "🎉 所有權限檢查通過！"
    echo "✅ 可以正常創建和管理 KV namespaces 和 R2 buckets"
    echo ""
    echo "🚀 建議下一步："
    echo "1. 運行完整部署: ./deploy-local.sh"
    echo "2. 或重新運行 GitHub Actions workflow"
    
elif [ $KV_LIST_EXIT_CODE -eq 0 ] && [ $TEST_CREATE_EXIT_CODE -ne 0 ]; then
    echo "⚠️  部分權限問題"
    echo "✅ 可以讀取 KV namespaces"
    echo "❌ 無法創建 KV namespaces"
    echo ""
    echo "🔧 建議解決方案："
    echo "1. 重新創建 API token 並確保有 'Cloudflare Workers:Edit' 權限"
    echo "2. 檢查帳戶是否達到 KV namespace 限制"
    echo "3. 設置 CLOUDFLARE_ACCOUNT_ID 環境變數"
    
else
    echo "❌ 嚴重權限問題"
    echo "API token 缺少必要的權限"
    echo ""
    echo "🔧 必須解決的問題："
    echo "1. 重新創建 API token"
    echo "2. 確保 token 有以下權限："
    echo "   - Account: Cloudflare Workers:Edit"
    echo "   - Account: Account Settings:Read"
    echo "   - Zone: Zone:Read (如果需要自定義域名)"
fi

echo ""
echo "🔗 有用的鏈接："
echo "- API Tokens 管理: https://dash.cloudflare.com/profile/api-tokens"
echo "- Workers Dashboard: https://dash.cloudflare.com/workers"
echo "- API 文檔: https://developers.cloudflare.com/api/"