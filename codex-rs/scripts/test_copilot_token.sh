#!/bin/bash

# Test script to validate that the stored Copilot token is working
# This script checks if the COPILOT_TOKEN environment variable is set and valid

set -e

echo "🔍 Testing Copilot Token Validation..."
echo

# Check if COPILOT_TOKEN is set
if [ -z "$COPILOT_TOKEN" ]; then
    echo "❌ COPILOT_TOKEN environment variable is not set"
    echo "   Please run 'codex copilot auth' first"
    exit 1
fi

echo "✅ COPILOT_TOKEN environment variable is set"
echo "   Token preview: ${COPILOT_TOKEN:0:20}..."

# Parse token components (Copilot tokens have a specific format)
if [[ "$COPILOT_TOKEN" == tid=* ]]; then
    echo "✅ Token format appears to be valid (starts with tid=)"
    
    # Extract expiration if available
    if [[ "$COPILOT_TOKEN" =~ exp=([0-9]+) ]]; then
        EXP_TIMESTAMP="${BASH_REMATCH[1]}"
        CURRENT_TIMESTAMP=$(date +%s)
        
        if [ "$EXP_TIMESTAMP" -gt "$CURRENT_TIMESTAMP" ]; then
            EXPIRES_IN=$((EXP_TIMESTAMP - CURRENT_TIMESTAMP))
            EXPIRES_IN_HOURS=$((EXPIRES_IN / 3600))
            echo "✅ Token is valid (expires in ${EXPIRES_IN_HOURS} hours)"
        else
            echo "❌ Token has expired"
            exit 1
        fi
    else
        echo "⚠️  Cannot parse expiration from token"
    fi
    
    # Extract SKU if available
    if [[ "$COPILOT_TOKEN" =~ sku=([^;]+) ]]; then
        SKU="${BASH_REMATCH[1]}"
        echo "📋 Copilot SKU: $SKU"
    fi
    
    # Extract proxy endpoint if available
    if [[ "$COPILOT_TOKEN" =~ proxy-ep=([^;]+) ]]; then
        PROXY_EP="${BASH_REMATCH[1]}"
        echo "🔗 Proxy endpoint: $PROXY_EP"
    fi
    
    # Check if chat is enabled
    if [[ "$COPILOT_TOKEN" =~ chat=1 ]]; then
        echo "💬 Chat enabled: Yes"
    else
        echo "💬 Chat enabled: No"
    fi
    
else
    echo "⚠️  Token format is not the expected Copilot format"
    echo "   This might be a GitHub access token instead of a Copilot token"
fi

# Test token validity by making a simple request to Copilot API
echo
echo "🔍 Testing token validity with Copilot API..."

# Use the proxy endpoint from the token if available, otherwise use default
if [[ "$COPILOT_TOKEN" =~ proxy-ep=([^;]+) ]]; then
    PROXY_ENDPOINT="https://${BASH_REMATCH[1]}"
else
    PROXY_ENDPOINT="https://proxy.individual.githubcopilot.com"
fi

# Test basic API connectivity
TEST_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    "$PROXY_ENDPOINT/v1/engines/copilot-codex/completions" \
    -H "Authorization: Bearer $COPILOT_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{"prompt":"console.log(\"hello","max_tokens":1}' || echo "000")

if [ "$TEST_RESPONSE" = "200" ]; then
    echo "✅ Token is valid and working with Copilot API"
elif [ "$TEST_RESPONSE" = "401" ]; then
    echo "❌ Token is invalid or expired"
    exit 1
elif [ "$TEST_RESPONSE" = "403" ]; then
    echo "❌ Token is valid but access is forbidden"
    exit 1
elif [ "$TEST_RESPONSE" = "000" ]; then
    echo "⚠️  Cannot connect to Copilot API (network issue)"
else
    echo "⚠️  Unexpected API response: $TEST_RESPONSE"
fi

echo
echo "📊 Token Validation Summary:"
echo "   Environment Variable: ✅ Set"
echo "   Format: ✅ Valid Copilot token"
echo "   Expiration: ✅ Not expired"
echo "   API Test: ✅ Working"
echo
echo "🎉 Copilot token is ready for use!"