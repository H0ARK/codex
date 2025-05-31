#!/bin/bash

# Cleanup script to remove low-value Zed crates from codex-rs/crates/
# Run from the codex-rs root directory

set -e

echo "🧹 Cleaning up Zed crates - removing low-value crates for Codex..."

# UI Components (Codex has its own UI)
echo "Removing UI components..."
rm -rf crates/gpui
rm -rf crates/gpui_macros
rm -rf crates/gpui_tokio
rm -rf crates/ui
rm -rf crates/ui_input
rm -rf crates/ui_macros
rm -rf crates/ui_prompt
rm -rf crates/theme
rm -rf crates/theme_extension
rm -rf crates/theme_importer
rm -rf crates/theme_selector
rm -rf crates/activity_indicator
rm -rf crates/breadcrumbs
rm -rf crates/command_palette
rm -rf crates/command_palette_hooks
rm -rf crates/editor
rm -rf crates/file_icons
rm -rf crates/image_viewer
rm -rf crates/inspector_ui
rm -rf crates/markdown_preview
rm -rf crates/menu
rm -rf crates/notifications
rm -rf crates/outline_panel
rm -rf crates/panel
rm -rf crates/picker
rm -rf crates/project_panel
rm -rf crates/settings_ui
rm -rf crates/snippets_ui
rm -rf crates/tab_switcher
rm -rf crates/tasks_ui
rm -rf crates/terminal_view
rm -rf crates/title_bar
rm -rf crates/welcome

# Zed-Specific Features
echo "Removing Zed-specific features..."
rm -rf crates/zed
rm -rf crates/zed_actions
rm -rf crates/auto_update
rm -rf crates/auto_update_helper
rm -rf crates/auto_update_ui
rm -rf crates/collab
rm -rf crates/collab_ui
rm -rf crates/call
rm -rf crates/channel
rm -rf crates/client
rm -rf crates/extensions_ui
rm -rf crates/feedback
rm -rf crates/install_cli
rm -rf crates/recent_projects
rm -rf crates/release_channel
rm -rf crates/remote
rm -rf crates/remote_server
rm -rf crates/session
rm -rf crates/telemetry
rm -rf crates/telemetry_events
rm -rf crates/workspace
rm -rf crates/worktree

# Development/Testing Tools
echo "Removing development/testing tools..."
rm -rf crates/storybook
rm -rf crates/story
rm -rf crates/schema_generator
rm -rf crates/docs_preprocessor
rm -rf crates/migrator

# Platform/Integration Specific
echo "Removing platform-specific integrations..."
rm -rf crates/audio
rm -rf crates/media
rm -rf crates/vim
rm -rf crates/vim_mode_setting
rm -rf crates/askpass
rm -rf crates/assets
rm -rf crates/clock
rm -rf crates/db
rm -rf crates/fsevent
rm -rf crates/livekit_api
rm -rf crates/livekit_client
rm -rf crates/node_runtime
rm -rf crates/sqlez
rm -rf crates/sqlez_macros

# Assistant/Agent UI (keeping core AI but removing UI)
echo "Removing assistant UI components..."
rm -rf crates/assistant_context_editor
rm -rf crates/assistant_slash_command
rm -rf crates/assistant_slash_commands
rm -rf crates/assistant_tool
rm -rf crates/assistant_tools

# Debugging Tools (keep diagnostics, remove UI)
echo "Removing debugging UI..."
rm -rf crates/dap
rm -rf crates/dap_adapters
rm -rf crates/debug_adapter_extension
rm -rf crates/debugger_tools
rm -rf crates/debugger_ui

# Extension System (keep core, remove UI)
echo "Removing extension UI..."
rm -rf crates/extension
rm -rf crates/extension_api
rm -rf crates/extension_cli
rm -rf crates/extension_host

# Misc Utilities
echo "Removing miscellaneous utilities..."
rm -rf crates/component
rm -rf crates/credentials_provider
rm -rf crates/eval
rm -rf crates/feature_flags
rm -rf crates/go_to_line
rm -rf crates/html_to_markdown
rm -rf crates/http_client_tls
rm -rf crates/icons
rm -rf crates/inline_completion
rm -rf crates/inline_completion_button
rm -rf crates/jj
rm -rf crates/jj_ui
rm -rf crates/journal
rm -rf crates/language_extension
rm -rf crates/language_models
rm -rf crates/language_selector
rm -rf crates/language_tools
rm -rf crates/languages
rm -rf crates/lmstudio
rm -rf crates/multi_buffer
rm -rf crates/prompt_store
rm -rf crates/proto
rm -rf crates/refineable
rm -rf crates/repl
rm -rf crates/reqwest_client
rm -rf crates/rich_text
rm -rf crates/rpc
rm -rf crates/rules_library
rm -rf crates/settings
rm -rf crates/snippet_provider
rm -rf crates/toolchain_selector
rm -rf crates/util_macros
rm -rf crates/web_search_providers
rm -rf crates/zeta
rm -rf crates/zlog
rm -rf crates/zlog_settings

echo "✅ Cleanup complete!"
echo ""
echo "🟢 KEPT (high-value crates):"
echo "AI Models: anthropic, bedrock, copilot, deepseek, google_ai, mistral, ollama, open_ai, supermaven*"
echo "Text Processing: rope, text, buffer_diff, language, language_model, streaming_diff"
echo "Search: fuzzy, search"
echo "Utilities: collections, util, http_client, markdown, paths, semantic_version, sum_tree, time_format"
echo ""
echo "🟡 REVIEW THESE (medium value - decide if you need them):"
echo "Dev Tools: lsp, diagnostics, prettier, project, snippet, task, terminal"
echo "File Ops: file_finder, project_symbols, fs, git, semantic_index, indexed_docs, outline, web_search"
echo ""
echo "Run 'find crates/ -maxdepth 1 -type d | wc -l' to see how many crates remain"