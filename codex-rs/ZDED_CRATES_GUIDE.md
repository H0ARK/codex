# Zed Crates Guide for Codex

A curated guide to Zed's 160+ crates, organized by value for extending Codex functionality.

## 🟢 HIGH VALUE - Keep These (26 crates)

### AI Providers & Language Models 🤖
These integrate with various AI services and provide the core intelligence for Codex:

- `anthropic` - Anthropic Claude API integration
- `bedrock` - AWS Bedrock AI services 
- `copilot` - GitHub Copilot integration (completions + chat)
- `deepseek` - DeepSeek AI model integration
- `google_ai` - Google AI/Gemini integration
- `mistral` - Mistral AI integration
- `ollama` - Local Ollama model integration
- `open_ai` - OpenAI API integration
- `supermaven` - Supermaven code completion
- `supermaven_api` - Supermaven API client

### Core Text & Language Processing 📝
Essential for code manipulation and analysis:

- `rope` - Efficient text data structure (Zed's famous rope implementation)
- `text` - Text manipulation utilities
- `buffer_diff` - Text diffing algorithms
- `language` - Language server protocol integration
- `language_model` - Language model abstractions
- `streaming_diff` - Real-time differential streaming

### Search & Discovery 🔍
Advanced search capabilities:

- `fuzzy` - Lightning-fast fuzzy search (excellent implementation)
- `search` - Advanced search utilities

### Core Utilities 🔧
General-purpose utilities that enhance functionality:

- `collections` - Enhanced collection types
- `util` - General utility functions
- `http_client` - HTTP client functionality
- `markdown` - Markdown processing
- `paths` - Path manipulation utilities
- `semantic_version` - Semantic versioning support
- `sum_tree` - Tree data structures
- `time_format` - Time formatting utilities

## 🟡 MEDIUM VALUE - Consider These (15 crates)

### Development Tools 🛠️
Useful for code analysis and tooling:

- `lsp` - Language Server Protocol implementation
- `diagnostics` - Error and warning diagnostics
- `prettier` - Code formatting integration
- `project` - Project management utilities
- `snippet` - Code snippet management
- `task` - Task execution framework
- `terminal` - Terminal integration

### File & Symbol Operations 📁
Advanced file and code navigation:

- `file_finder` - File discovery utilities
- `project_symbols` - Symbol indexing and search
- `fs` - File system utilities
- `git` - Git integration
- `semantic_index` - Semantic code indexing
- `indexed_docs` - Documentation indexing
- `outline` - Code structure analysis
- `web_search` - Web search integration

## 🔴 LOW VALUE - Safe to Remove (120+ crates)

### UI Components (Codex has its own interface)
All UI-related crates since Codex uses its own interface:
- `gpui*` - GPU UI framework
- `ui*` - UI components and utilities
- `theme*` - Theming system
- `*_ui` - All UI panels and components
- `editor` - Text editor component
- `picker` - Selection interfaces
- `menu` - Menu systems
- `notifications` - Notification system

### Zed-Specific Features
Features specific to the Zed editor:
- `zed` - Main Zed application
- `zed_actions` - Zed-specific actions
- `auto_update*` - Auto-update system
- `collab*` - Collaboration features
- `call` - Video calling
- `channel` - Chat channels
- `workspace` - Zed workspace management
- `session` - Session management
- `telemetry*` - Analytics and telemetry

### Development/Testing Infrastructure
Internal tooling not needed for extensions:
- `storybook` - UI component testing
- `story` - UI story framework
- `schema_generator` - Schema generation tools
- `docs_preprocessor` - Documentation tools
- `migrator` - Database migration tools

### Platform-Specific Integrations
Features tied to specific platforms or tools:
- `audio` - Audio system
- `media` - Media handling
- `vim*` - Vim mode implementation
- `askpass` - Password prompts
- `livekit*` - Video conferencing
- `node_runtime` - Node.js runtime
- `sqlez*` - Database utilities

### Extension System UI
Keep core extension functionality, remove UI:
- `extension_host` - Extension hosting (keep if building extensions)
- `extensions_ui` - Extension management UI (remove)
- `assistant_*_ui` - Assistant interface components (remove)

## 🚀 Quick Start Cleanup

### Option 1: Aggressive (Keep ~25 crates)
```bash
cd codex-rs
./scripts/interactive_cleanup.sh
# Choose option 1
```

### Option 2: Selective (Keep ~40 crates)  
```bash
cd codex-rs
./scripts/interactive_cleanup.sh
# Choose option 2
```

### Option 3: Custom
```bash
cd codex-rs
./scripts/interactive_cleanup.sh
# Choose option 3 for interactive selection
```

## 📊 Expected Results

- **Before**: ~160 crates
- **After Aggressive**: ~25 crates (AI providers + text processing + utilities)
- **After Selective**: ~40 crates (+ development tools + file operations)
- **Disk Space Saved**: ~80-90% reduction

## 🎯 Integration Priority

If you're planning to integrate these crates into Codex, start with:

1. **AI Providers** - `anthropic`, `copilot`, `open_ai`, `ollama` (choose based on your needs)
2. **Text Processing** - `rope`, `fuzzy`, `language` 
3. **Utilities** - `collections`, `util`, `markdown`
4. **Search** - `search`, `semantic_index` (if building advanced search)
5. **Development Tools** - `lsp`, `diagnostics` (if building language analysis)

## ⚠️ Important Notes

- Most Zed crates are **not published** to crates.io - use git dependencies
- Some crates have **heavy dependencies** (especially UI-related ones)
- **API stability** varies - published crates are more stable
- Consider **licensing** - Zed uses GPL-3.0-or-later for most crates

## 🔗 Usage Examples

```toml
# In your Cargo.toml
[dependencies]
# Published crates (stable)
zed_extension_api = "0.5.0"

# Git dependencies (latest)
rope = { git = "https://github.com/zed-industries/zed", path = "crates/rope" }
fuzzy = { git = "https://github.com/zed-industries/zed", path = "crates/fuzzy" }
anthropic = { git = "https://github.com/zed-industries/zed", path = "crates/anthropic" }
```