#!/bin/bash

# Interactive cleanup script for Zed crates
# Run from codex-rs root directory

set -e

echo "🧹 Interactive Zed Crates Cleanup for Codex"
echo "============================================="
echo

# Count current crates
TOTAL_CRATES=$(find crates/ -maxdepth 1 -type d | wc -l)
echo "Current crates: $((TOTAL_CRATES - 1))"
echo

# Function to prompt for yes/no
ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local response
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to remove crates
remove_crates() {
    local category="$1"
    shift
    local crates=("$@")
    
    echo "Removing $category..."
    for crate in "${crates[@]}"; do
        if [ -d "crates/$crate" ]; then
            rm -rf "crates/$crate"
            echo "  ✓ Removed $crate"
        fi
    done
    echo
}

echo "Choose cleanup level:"
echo "1) 🔥 Aggressive (keep only 25 high-value crates)"
echo "2) 🎯 Selective (keep 40 medium+ value crates)" 
echo "3) 🧹 Custom (choose categories interactively)"
echo "4) 📋 List all crates and exit"
echo

read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo "🔥 AGGRESSIVE CLEANUP - Keeping only high-value crates"
        if ask_yes_no "This will remove ~140 crates. Continue?" "n"; then
            # Keep only the cream of the crop
            KEEP_CRATES=(
                "anthropic" "bedrock" "copilot" "deepseek" "google_ai" "mistral" "ollama" "open_ai"
                "rope" "text" "buffer_diff" "language" "language_model" "streaming_diff"
                "fuzzy" "search" "collections" "util" "http_client" "markdown" 
                "paths" "semantic_version" "sum_tree" "time_format" "supermaven" "supermaven_api"
            )
            
            # Remove everything except kept crates
            for crate_dir in crates/*/; do
                crate=$(basename "$crate_dir")
                if [[ ! " ${KEEP_CRATES[@]} " =~ " ${crate} " ]]; then
                    rm -rf "$crate_dir"
                    echo "  ✓ Removed $crate"
                fi
            done
            
            echo "✅ Aggressive cleanup complete! Kept ${#KEEP_CRATES[@]} crates."
        fi
        ;;
        
    2)
        echo "🎯 SELECTIVE CLEANUP - Keeping medium+ value crates"
        if ask_yes_no "This will remove ~120 crates. Continue?" "n"; then
            # Remove the obvious junk first
            UI_CRATES=(
                "gpui" "gpui_macros" "gpui_tokio" "ui" "ui_input" "ui_macros" "ui_prompt"
                "theme" "theme_extension" "theme_importer" "theme_selector" "activity_indicator"
                "breadcrumbs" "command_palette" "command_palette_hooks" "editor" "file_icons"
                "image_viewer" "inspector_ui" "markdown_preview" "menu" "notifications"
                "outline_panel" "panel" "picker" "project_panel" "settings_ui" "snippets_ui"
                "tab_switcher" "tasks_ui" "terminal_view" "title_bar" "welcome"
            )
            
            ZED_SPECIFIC=(
                "zed" "zed_actions" "auto_update" "auto_update_helper" "auto_update_ui"
                "collab" "collab_ui" "call" "channel" "client" "extensions_ui" "feedback"
                "install_cli" "recent_projects" "release_channel" "remote" "remote_server"
                "session" "telemetry" "telemetry_events" "workspace" "worktree"
            )
            
            PLATFORM_SPECIFIC=(
                "audio" "media" "vim" "vim_mode_setting" "askpass" "assets"
                "clock" "db" "fsevent" "livekit_api" "livekit_client" "node_runtime"
                "sqlez" "sqlez_macros" "storybook" "story" "schema_generator"
            )
            
            remove_crates "UI components" "${UI_CRATES[@]}"
            remove_crates "Zed-specific features" "${ZED_SPECIFIC[@]}"
            remove_crates "Platform-specific" "${PLATFORM_SPECIFIC[@]}"
            
            echo "✅ Selective cleanup complete!"
        fi
        ;;
        
    3)
        echo "🧹 CUSTOM CLEANUP - Choose what to remove"
        echo
        
        if ask_yes_no "Remove UI components? (gpui, themes, panels, etc.)" "y"; then
            UI_CRATES=(
                "gpui" "gpui_macros" "gpui_tokio" "ui" "ui_input" "ui_macros" "ui_prompt"
                "theme" "theme_extension" "theme_importer" "theme_selector" "activity_indicator"
                "breadcrumbs" "command_palette" "command_palette_hooks" "editor" "file_icons"
                "image_viewer" "inspector_ui" "markdown_preview" "menu" "notifications"
                "outline_panel" "panel" "picker" "project_panel" "settings_ui" "snippets_ui"
                "tab_switcher" "tasks_ui" "terminal_view" "title_bar" "welcome"
            )
            remove_crates "UI components" "${UI_CRATES[@]}"
        fi
        
        if ask_yes_no "Remove Zed-specific features? (collaboration, auto-update, etc.)" "y"; then
            ZED_SPECIFIC=(
                "zed" "zed_actions" "auto_update" "auto_update_helper" "auto_update_ui"
                "collab" "collab_ui" "call" "channel" "client" "extensions_ui" "feedback"
                "install_cli" "recent_projects" "release_channel" "remote" "remote_server"
                "session" "telemetry" "telemetry_events" "workspace" "worktree"
            )
            remove_crates "Zed-specific features" "${ZED_SPECIFIC[@]}"
        fi
        
        if ask_yes_no "Remove development/testing tools? (storybook, schema generator, etc.)" "y"; then
            DEV_TOOLS=(
                "storybook" "story" "schema_generator" "docs_preprocessor" "migrator"
                "dap" "dap_adapters" "debug_adapter_extension" "debugger_tools" "debugger_ui"
            )
            remove_crates "Development tools" "${DEV_TOOLS[@]}"
        fi
        
        if ask_yes_no "Remove platform integrations? (vim, audio, media, etc.)" "y"; then
            PLATFORM_SPECIFIC=(
                "audio" "media" "vim" "vim_mode_setting" "askpass" "assets"
                "clock" "db" "fsevent" "livekit_api" "livekit_client" "node_runtime"
                "sqlez" "sqlez_macros"
            )
            remove_crates "Platform integrations" "${PLATFORM_SPECIFIC[@]}"
        fi
        
        if ask_yes_no "Remove extension system? (keep only core language models)" "n"; then
            EXTENSION_SYSTEM=(
                "extension" "extension_api" "extension_cli" "extension_host"
                "assistant_context_editor" "assistant_slash_command" "assistant_slash_commands"
                "assistant_tool" "assistant_tools"
            )
            remove_crates "Extension system" "${EXTENSION_SYSTEM[@]}"
        fi
        
        echo "✅ Custom cleanup complete!"
        ;;
        
    4)
        echo "📋 All crates in alphabetical order:"
        echo "=================================="
        find crates/ -maxdepth 1 -type d -name "*" | sort | sed 's/crates\///' | grep -v '^$'
        echo
        exit 0
        ;;
        
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

# Final count
FINAL_CRATES=$(find crates/ -maxdepth 1 -type d | wc -l)
REMOVED=$((TOTAL_CRATES - FINAL_CRATES))

echo
echo "📊 Summary:"
echo "  Started with: $((TOTAL_CRATES - 1)) crates"
echo "  Removed: $REMOVED crates"
echo "  Remaining: $((FINAL_CRATES - 1)) crates"
echo
echo "🎯 Recommended next steps:"
echo "  1. Update Cargo.toml workspace members"
echo "  2. Run 'cargo check' to verify no broken dependencies"
echo "  3. Review remaining crates with: ls crates/"
echo
echo "🟢 High-value crates you should definitely keep:"
echo "  AI: anthropic, copilot, deepseek, google_ai, mistral, ollama, open_ai"
echo "  Text: rope, text, buffer_diff, language, fuzzy, search"
echo "  Utils: collections, util, markdown, paths, semantic_version"