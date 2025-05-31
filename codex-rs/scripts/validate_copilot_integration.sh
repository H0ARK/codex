#!/bin/bash

# Copilot Integration Validation Script
# This script validates that GitHub Copilot integration is working properly

set -e

echo "🔍 Validating Copilot Integration..."
echo

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ] || [ ! -d "core" ]; then
    echo "❌ Error: This script must be run from the codex-rs root directory"
    exit 1
fi

echo "✅ Found codex-rs project structure"

# 1. Build check
echo "📦 Building project with CLI features..."
if cargo check --features cli --quiet; then
    echo "✅ Project builds successfully"
else
    echo "❌ Build failed"
    exit 1
fi

# 2. Run Copilot validation tests
echo "🧪 Running Copilot validation tests..."
if cargo test --package codex-core copilot_validation --features cli --quiet; then
    echo "✅ All Copilot validation tests passed"
else
    echo "❌ Copilot validation tests failed"
    exit 1
fi

# 3. Check CLI command availability
echo "🛠️  Checking CLI command availability..."
if cargo run --bin codex --features cli -- copilot --help > /dev/null 2>&1; then
    echo "✅ Copilot CLI command is available"
else
    echo "❌ Copilot CLI command not available"
    exit 1
fi

# 4. Check auth subcommand
echo "🔑 Checking auth subcommand..."
if cargo run --bin codex --features cli -- copilot auth --help > /dev/null 2>&1; then
    echo "✅ Copilot auth command is available"
else
    echo "❌ Copilot auth command not available"
    exit 1
fi

# 5. Validate dependencies
echo "📋 Checking required dependencies..."
REQUIRED_DEPS=("reqwest" "serde_json" "async-channel" "tokio")
for dep in "${REQUIRED_DEPS[@]}"; do
    if grep -q "^$dep" core/Cargo.toml; then
        echo "✅ Dependency '$dep' found"
    else
        echo "❌ Missing dependency: $dep"
        exit 1
    fi
done

# 6. Check roadmap file exists
echo "📄 Checking documentation..."
if [ -f "COPILOT_INTEGRATION_ROADMAP.md" ]; then
    echo "✅ Copilot integration roadmap found"
else
    echo "⚠️  Warning: Copilot integration roadmap not found"
fi

# 7. Validate protocol definitions
echo "🔌 Checking protocol integration..."
if grep -q "CopilotAuth" core/src/protocol.rs; then
    echo "✅ CopilotAuth operation defined in protocol"
else
    echo "❌ CopilotAuth operation not found in protocol"
    exit 1
fi

if grep -q "CopilotAuthStartedEvent\|CopilotAuthCompleteEvent" core/src/protocol.rs; then
    echo "✅ Copilot events defined in protocol"
else
    echo "❌ Copilot events not found in protocol"
    exit 1
fi

# 8. Check feature flags
echo "🏁 Checking feature configuration..."
if grep -q 'cli = \["codex-common/cli"\]' core/Cargo.toml; then
    echo "✅ CLI feature properly configured"
else
    echo "❌ CLI feature not properly configured"
    exit 1
fi

echo
echo "🎉 Copilot Integration Validation Summary:"
echo "   ✅ Project builds successfully"
echo "   ✅ All validation tests pass"
echo "   ✅ CLI commands are accessible"
echo "   ✅ Required dependencies present"
echo "   ✅ Protocol integration complete"
echo "   ✅ Feature flags configured"
echo
echo "📋 Current Status: Phase 1 (Basic Integration) ✅"
echo "🔗 Authentication: GitHub Device Flow"
echo "🛠️  Available Commands:"
echo "   • codex copilot auth"
echo
echo "📖 For usage examples, see COPILOT_INTEGRATION_ROADMAP.md"
echo "🚀 Integration is ready for use!"