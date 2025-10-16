#!/bin/bash

# KV 創建調試腳本
# 專門用於調試 KV namespace 創建問題

echo "🔍 KV Namespace 創建調試腳本"
echo "============================"

# 檢查環境
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN 未設置"
    echo "請設置後重試：export CLOUDFLARE_API_TOKEN=your_token_here"
    exit 1
fi

echo "✅ API Token 已設置"

# 測試基本連接
echo ""
echo "🔐 測試 Cloudflare 連接..."
npx wrangler whoami

# 嘗試創建 KV namespace 並捕獲所有輸出
echo ""
echo "🗄️  嘗試創建 KV namespace..."
echo "命令: npx wrangler kv namespace create filecodebox-kv-2c88c777"

# 使用 script 命令捕獲所有輸出（包括顏色和格式）
echo ""
echo "📋 完整輸出："
echo "=============="

# 方法 1: 直接執行並顯示所有輸出
set +e
npx wrangler kv namespace create "filecodebox-kv-2c88c777" 2>&1 | tee kv_creation_output.log
KV_EXIT_CODE=${PIPESTATUS[0]}
set -e

echo ""
echo "📊 執行結果："
echo "- 退出代碼: $KV_EXIT_CODE"
echo "- 輸出已保存到: kv_creation_output.log"

if [ $KV_EXIT_CODE -eq 0 ]; then
    echo "✅ KV namespace 創建成功！"
    
    # 提取 ID
    KV_ID=$(cat kv_creation_output.log | grep -o 'id = "[^"]*"' | sed 's/id = "\(.*\)"/\1/')
    if [ -n "$KV_ID" ]; then
        echo "📋 KV ID: $KV_ID"
    fi
else
    echo "❌ KV namespace 創建失敗"
    echo ""
    echo "🔍 錯誤分析："
    
    # 讀取輸出文件進行分析
    if [ -f kv_creation_output.log ]; then
        OUTPUT_CONTENT=$(cat kv_creation_output.log)
        
        echo "完整錯誤輸出："
        echo "---------------"
        cat kv_creation_output.log
        echo "---------------"
        echo ""
        
        # 分析常見錯誤
        if echo "$OUTPUT_CONTENT" | grep -qi "permission\|forbidden\|unauthorized\|access denied"; then
            echo "🚨 權限錯誤："
            echo "- API token 缺少必要權限"
            echo "- 需要 'Cloudflare Workers:Edit' 權限"
            echo "- 前往 https://dash.cloudflare.com/profile/api-tokens 檢查權限"
            
        elif echo "$OUTPUT_CONTENT" | grep -qi "account"; then
            echo "🚨 帳戶錯誤："
            echo "- 可能需要設置 CLOUDFLARE_ACCOUNT_ID"
            echo "- 或者帳戶沒有 Workers 功能"
            
        elif echo "$OUTPUT_CONTENT" | grep -qi "limit\|quota\|exceeded"; then
            echo "🚨 配額錯誤："
            echo "- 帳戶已達到 KV namespace 限制"
            echo "- 免費帳戶通常限制為 1 個 namespace"
            echo "- 需要刪除現有的或升級計劃"
            
        elif echo "$OUTPUT_CONTENT" | grep -qi "network\|timeout\|connection\|dns"; then
            echo "🚨 網絡錯誤："
            echo "- 網絡連接問題"
            echo "- DNS 解析問題"
            echo "- 請檢查網絡連接"
            
        elif echo "$OUTPUT_CONTENT" | grep -qi "already exists\|duplicate"; then
            echo "🚨 重複錯誤："
            echo "- KV namespace 已存在"
            echo "- 這通常不是錯誤，可以繼續使用現有的"
            
        else
            echo "🚨 未知錯誤："
            echo "- 請檢查上面的完整錯誤輸出"
            echo "- 可能需要聯繫 Cloudflare 支持"
        fi
    fi
fi

# 嘗試列出現有的 KV namespaces
echo ""
echo "📋 列出現有的 KV namespaces..."
echo "命令: npx wrangler kv namespace list"

set +e
npx wrangler kv namespace list 2>&1 | tee kv_list_output.log
LIST_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $LIST_EXIT_CODE -eq 0 ]; then
    echo "✅ 成功列出 KV namespaces"
    
    # 檢查是否已有目標 namespace
    if grep -q "filecodebox-kv-2c88c777" kv_list_output.log; then
        echo "✅ 找到現有的 filecodebox-kv-2c88c777 namespace"
        
        # 嘗試提取 ID
        EXISTING_ID=$(cat kv_list_output.log | grep "filecodebox-kv-2c88c777" | grep -o 'id: [a-f0-9]*' | cut -d' ' -f2)
        if [ -n "$EXISTING_ID" ]; then
            echo "📋 現有 KV ID: $EXISTING_ID"
        fi
    else
        echo "ℹ️  未找到 filecodebox-kv-2c88c777 namespace"
    fi
else
    echo "❌ 無法列出 KV namespaces"
fi

# 檢查帳戶限制
echo ""
echo "📊 帳戶信息檢查..."

# 嘗試獲取帳戶信息
set +e
ACCOUNT_INFO=$(npx wrangler whoami 2>&1)
set -e

if echo "$ACCOUNT_INFO" | grep -q "Account ID"; then
    ACCOUNT_ID=$(echo "$ACCOUNT_INFO" | grep "Account ID" | awk -F'│' '{print $3}' | tr -d ' ')
    echo "📋 Account ID: $ACCOUNT_ID"
    
    # 檢查是否設置了環境變數
    if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
        echo "✅ CLOUDFLARE_ACCOUNT_ID 環境變數已設置"
        if [ "$CLOUDFLARE_ACCOUNT_ID" = "$ACCOUNT_ID" ]; then
            echo "✅ Account ID 匹配"
        else
            echo "⚠️  Account ID 不匹配"
            echo "   環境變數: $CLOUDFLARE_ACCOUNT_ID"
            echo "   實際 ID: $ACCOUNT_ID"
        fi
    else
        echo "⚠️  CLOUDFLARE_ACCOUNT_ID 環境變數未設置"
        echo "💡 嘗試設置: export CLOUDFLARE_ACCOUNT_ID=$ACCOUNT_ID"
    fi
fi

# 總結和建議
echo ""
echo "📋 調試總結"
echo "==========="

if [ $KV_EXIT_CODE -eq 0 ]; then
    echo "🎉 KV namespace 創建成功！可以繼續部署。"
elif [ $LIST_EXIT_CODE -eq 0 ] && grep -q "filecodebox-kv-2c88c777" kv_list_output.log; then
    echo "✅ KV namespace 已存在，可以使用現有的。"
else
    echo "❌ KV namespace 創建失敗，需要解決以下問題："
    echo ""
    echo "🔧 建議的解決步驟："
    echo "1. 檢查 API token 權限："
    echo "   - 前往 https://dash.cloudflare.com/profile/api-tokens"
    echo "   - 確保有 'Cloudflare Workers:Edit' 權限"
    echo ""
    echo "2. 設置 Account ID（如果未設置）："
    echo "   export CLOUDFLARE_ACCOUNT_ID=your_account_id"
    echo ""
    echo "3. 檢查帳戶限制："
    echo "   - 免費帳戶可能只能創建 1 個 KV namespace"
    echo "   - 查看 https://dash.cloudflare.com/workers 的配額使用情況"
    echo ""
    echo "4. 如果是配額問題，刪除未使用的 KV namespaces："
    echo "   npx wrangler kv namespace delete --namespace-id <id>"
fi

# 清理臨時文件
echo ""
echo "🧹 清理臨時文件..."
rm -f kv_creation_output.log kv_list_output.log
echo "✅ 清理完成"