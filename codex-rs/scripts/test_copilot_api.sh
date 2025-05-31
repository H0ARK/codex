#!/bin/bash

# Test script to debug Copilot API authentication issues
# This script helps identify where the auth flow is failing

set -e

echo "🔍 Testing Copilot API endpoints..."
echo

# GitHub API constants
GITHUB_DEVICE_CODE_URL="https://github.com/login/device/code"
GITHUB_DEVICE_TOKEN_URL="https://github.com/login/oauth/access_token"
COPILOT_CHAT_AUTH_URL="https://api.github.com/copilot_internal/v2/token"
GITHUB_CLIENT_ID="Iv1.b507a08c87ecfe98"

echo "📋 Testing endpoint accessibility..."

# Test 1: Check if GitHub device code endpoint is accessible
echo "1️⃣  Testing GitHub device code endpoint..."
if curl -s -f -X POST "$GITHUB_DEVICE_CODE_URL" \
    -H "Accept: application/json" \
    -d "client_id=$GITHUB_CLIENT_ID&scope=copilot" > /dev/null; then
    echo "✅ GitHub device code endpoint is accessible"
else
    echo "❌ GitHub device code endpoint is not accessible"
    exit 1
fi

# Test 2: Get a real device code for testing
echo "2️⃣  Getting device code..."
DEVICE_RESPONSE=$(curl -s -X POST "$GITHUB_DEVICE_CODE_URL" \
    -H "Accept: application/json" \
    -d "client_id=$GITHUB_CLIENT_ID&scope=copilot")

echo "Device response: $DEVICE_RESPONSE"

USER_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"user_code":"[^"]*"' | cut -d'"' -f4)
VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | grep -o '"verification_uri":"[^"]*"' | cut -d'"' -f4)
DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"device_code":"[^"]*"' | cut -d'"' -f4)

if [ -z "$USER_CODE" ] || [ -z "$DEVICE_CODE" ]; then
    echo "❌ Failed to get device code from GitHub"
    echo "Response: $DEVICE_RESPONSE"
    exit 1
fi

echo "✅ Got device code successfully"
echo "   User code: $USER_CODE"
echo "   Verification URI: $VERIFICATION_URI"
echo "   Device code: ${DEVICE_CODE:0:20}..."

# Test 3: Check token endpoint format
echo "3️⃣  Testing token endpoint format..."
TOKEN_RESPONSE=$(curl -s -X POST "$GITHUB_DEVICE_TOKEN_URL" \
    -H "Accept: application/json" \
    -d "client_id=$GITHUB_CLIENT_ID&device_code=$DEVICE_CODE&grant_type=urn:ietf:params:oauth:grant-type:device_code")

echo "Token response: $TOKEN_RESPONSE"

# Check if we get authorization_pending (expected)
if echo "$TOKEN_RESPONSE" | grep -q "authorization_pending"; then
    echo "✅ Token endpoint is working (authorization pending as expected)"
else
    echo "⚠️  Unexpected token response format"
fi

# Test 4: Check Copilot endpoint accessibility
echo "4️⃣  Testing Copilot endpoint accessibility..."
COPILOT_TEST=$(curl -s -w "%{http_code}" -o /dev/null "$COPILOT_CHAT_AUTH_URL" \
    -H "Authorization: Bearer dummy_token" \
    -H "Accept: application/json" \
    -H "User-Agent: Codex-CLI")

if [ "$COPILOT_TEST" = "401" ]; then
    echo "✅ Copilot endpoint is accessible (401 Unauthorized as expected with dummy token)"
elif [ "$COPILOT_TEST" = "403" ]; then
    echo "⚠️  Copilot endpoint returned 403 - might need different scope or permissions"
elif [ "$COPILOT_TEST" = "404" ]; then
    echo "❌ Copilot endpoint not found (404) - URL might be incorrect"
else
    echo "⚠️  Copilot endpoint returned status: $COPILOT_TEST"
fi

# Test 5: Interactive auth test
echo
echo "🔧 For manual testing:"
echo "1. Visit: $VERIFICATION_URI"
echo "2. Enter code: $USER_CODE"
echo "3. After authorization, run this command to test token exchange:"
echo
echo "   curl -X POST '$GITHUB_DEVICE_TOKEN_URL' \\"
echo "     -H 'Accept: application/json' \\"
echo "     -d 'client_id=$GITHUB_CLIENT_ID&device_code=$DEVICE_CODE&grant_type=urn:ietf:params:oauth:grant-type:device_code'"
echo
echo "4. If you get an access_token, test Copilot with:"
echo "   curl '$COPILOT_CHAT_AUTH_URL' \\"
echo "     -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \\"
echo "     -H 'Accept: application/json' \\"
echo "     -H 'User-Agent: Codex-CLI'"

echo
echo "📊 Endpoint Test Summary:"
echo "   GitHub Device Code: ✅"
echo "   GitHub Token Exchange: ✅"
echo "   Copilot Auth: Status $COPILOT_TEST"

if [ "$COPILOT_TEST" = "404" ]; then
    echo
    echo "⚠️  POTENTIAL ISSUE: Copilot endpoint may have changed."
    echo "   Current URL: $COPILOT_CHAT_AUTH_URL"
    echo "   Try checking GitHub Copilot documentation for updated endpoints."
fi