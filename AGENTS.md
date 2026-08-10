# AGENTS.md

## Project Structure
### Function
- Chinese language learning assistant (Product Name: **TingXieFlow**)
    - Smart 听写: The app uses native Apple TTS to read out dictation content using `AVSpeechSynthesizer`.
    - 错词 organization: Local Ollama (llama3 / gemma2) generates modern contextual sentences containing the user's specific 错词 via local JSON streaming.
    - 成语 logs: When an idiom is saved, the local LLM generates a casual sentence using it, adding custom tags (e.g., #joy, #sad, #humorous) and a breakdown of individual character meanings.
    - Smart Audio Controls: Allows language learners to dynamically speed up/slow down the TTS voice or add pronunciation profile variations (Mainland vs. Taiwanese Mandarin).
    - Automatic Anki Export: One-click button compiles collected words, generated sentences, and audio paths, packaging them into an `.apkg` file for Anki.
- **Audience:** Foreign speakers learning Chinese OR elementary to early middle school students working on Chinese learning.

### Structure
- Environment: Native macOS Application (Xcode project utilizing Swift 6 and SwiftUI).
- Storage: Local persistence managed exclusively via **SwiftData**. No cloud backends.

### Design Style
- **Theme:** Clean, native macOS desktop aesthetic (supports Light/Dark mode).
- **Layout:** `NavigationSplitView` architecture featuring a standard Sidebar navigation and a Main workspace dashboard.

## Commands
### GitHub Commits
When told to reformat commits, follow the Conventional Commits (https://www.conventionalcommits.org/en/v1.0.0/) format.

**Structure:** <type>[optional scope]: <description>
- **Type:** Define the nature of the change.
    * feat: Adding a new feature.
    * fix: Resolving a bug.
    * docs: Changes to documentation or README.
    * refactor: Code restructuring without changing behavior.
    * perf: Performance-related improvements.
    * test: Adding or updating tests.
- **Scope (optional):** The specific area of the project affected (audio, models, views, db, network, packaging)
- **Summary:** A concise, imperative sentence (e.g., Add support for...). Use the imperative mood (e.g., "Add," not "Added").

## Boundaries
### Do
- Write modular, highly reusable SwiftUI components.
- Use explicit async/await patterns for local LLM networking calls to keep the main UI thread responsive.
- Utilize native Apple symbols (`Image(systemName: ...)`) for iconography.

### Don't
- Do not import heavy external web wrappers or cross-platform dependencies.
- Do not commit local sensitive system paths or hardcoded developer configurations.
- Do not mutate SwiftData contexts directly on the Main Thread without explicit background handling.

### Safety & Permissions
Allowed without prompt:
- Read local project files, inspect directory hierarchies.

Ask first:
- Changing target macOS deployment build versions or modifying underlying build build settings.

## Documentation
- **Helpful Commenting:** Keep comments concise and focused on "Why" something is being done.
    - Use single-line explanations that provide property wrapper context (e.g., explaining `@State` vs `@Binding`).
- After completing any coding or design task, you must update the "# Project Log" section of this file. Include date, action, and files affected.
- Format: "**YYYY-MM-DD**: [Brief description of changes with which files were edited]"

# Project Log
- **2026-08-10**: Added concise one-line responsibility comments across every Swift source file and documented the main model, service, workflow, and reusable view blocks without narrating routine implementation details. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/Item.swift`, `TingXieFlow/Models/DictationSet.swift`, `TingXieFlow/Models/VocabularyWord.swift`, `TingXieFlow/Services/AppPreferences.swift`, `TingXieFlow/Services/CCCEDICTDictionary.swift`, `TingXieFlow/Services/DictationStore.swift`, `TingXieFlow/Services/LLM.swift`, `TingXieFlow/Services/SpeechAudioEngine.swift`, `TingXieFlow/TingXieFlowApp.swift`, `TingXieFlow/Views/LLMTestView.swift`, `TingXieFlow/Views/SettingsDashboard.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/SpeechTestView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-08-09**: Opted SwiftData models and the set-save payload out of the target's default MainActor isolation so their initializers execute safely inside `DictationStore`'s model actor instead of corrupting create-set arguments at the actor boundary. Files edited: `TingXieFlow/Models/DictationSet.swift`, `TingXieFlow/Models/VocabularyWord.swift`, `TingXieFlow/Services/DictationStore.swift`, `AGENTS.md`.
- **2026-08-09**: Moved set-editor errors beside Set Name with a red warning icon and prevented edit saves from capturing a live SwiftData model across task boundaries by snapshotting values and resolving the set inside its model actor. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Services/DictationStore.swift`, `AGENTS.md`.
- **2026-08-09**: Kept the Fill Details action compact and on one line, and made Create Set surface missing-name, missing-word, or in-progress enrichment requirements instead of silently ignoring clicks. Files edited: `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `AGENTS.md`.
- **2026-08-08**: Added an offline CC-CEDICT vocabulary service with exact simplified and traditional word lookup, deterministic tone-mark conversion, concise English definitions, cached batch resolution, Apple transliteration and Local AI fallbacks, bundled attribution, settings credit, and dictionary-first set creation. Files edited: `TingXieFlow/Services/CCCEDICTDictionary.swift`, `TingXieFlow/Resources/cedict_ts.u8`, `TingXieFlow/Resources/CC-CEDICT-NOTICE.txt`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/SettingsDashboard.swift`, `AGENTS.md`.
- **2026-08-08**: Added a selectable Local AI model-output panel beneath the enrichment input, showing initial and repair responses separately with a combined Copy action. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `DESIGN.md`, `AGENTS.md`.
- **2026-08-08**: Refocused new-set Local AI on enriching user-supplied Chinese words separated by commas, spaces, punctuation, or new lines; preserved and validated input order, filled pinyin and English translations, removed generated-count settings, and updated product documentation. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/SettingsDashboard.swift`, `TingXieFlow/Services/AppPreferences.swift`, `DESIGN.md`, `TODO.md`, `AGENTS.md`.
- **2026-08-08**: Isolated local LLM request history by caching the model instead of a shared chat session, added strict system formatting guidance, delimited learner input, accepted full-width field separators, preserved translations containing separators, and added one repair attempt for malformed generated vocabulary. Files edited: `TingXieFlow/Services/LLM.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `AGENTS.md`.
- **2026-08-08**: Reverted the Liquid Glass redesign to the prior TingXieFlow aesthetic, restoring the custom collapsible and persistently resizable sidebar, hidden title bar, solid accent actions, tonal search and filter surfaces, bordered secondary controls, and original material treatments while retaining newer search behavior and content spacing. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/TingXieFlowApp.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `DESIGN.md`, `AGENTS.md`.
- **2026-08-08**: Increased the empty dictation card's horizontal and vertical content insets so its icon, copy, and action remain comfortably separated from the rounded edges. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `AGENTS.md`.
- **2026-08-08**: Restored the Word of the Day card's original selection fill and outline beneath clear interactive glass, made clear-glass fallbacks color-neutral, and extended the sidebar background through the safe area to prevent expanded-window color gaps. Files edited: `TingXieFlow/Views/TingXieTheme.swift`, `DESIGN.md`, `AGENTS.md`.
- **2026-08-08**: Restored the original TingXieFlow background, sidebar, surface, accent, text, outline, missed-state, and sheet colors while retaining the Liquid Glass interface and search improvements. Files edited: `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `DESIGN.md`, `AGENTS.md`.
- **2026-08-08**: Migrated the app to a native NavigationSplitView and unified toolbar, added macOS 26 Liquid Glass with macOS 15 material fallbacks, converted navigation, search, filter, sheet, playback, and primary action controls to the functional glass layer, made search highlights transparent, introduced adaptive Light/Dark palette and accessibility behavior, and documented the new visual architecture. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/TingXieFlowApp.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `DESIGN.md`, `AGENTS.md`.
- **2026-08-07**: Prevented anchored search result lists from collapsing below their count headers and expanded the practice-card progress bar across all available bottom-row space. Files edited: `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `AGENTS.md`.
- **2026-08-07**: Reworked dictation and vocabulary search into anchored live-result panels with clear, keyboard, accessibility, translation, and normalized pinyin matching, kept normal workspace content stable during searches, and expanded the Vocabulary Inspector playback control into a full-width audio bar. Files edited: `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-08-06**: Removed the Open Diagnostics action and its unused speech-test sheet state from Speech & Pronunciation Settings. Files edited: `TingXieFlow/Views/SettingsDashboard.swift`, `AGENTS.md`.
- **2026-08-06**: Removed the Local AI and Data & Export Settings cards, aligned the Speech & Pronunciation and Practice cards to a shared height, and placed About in a full-width row. Files edited: `TingXieFlow/Views/SettingsDashboard.swift`, `AGENTS.md`.
- **2026-08-06**: Consolidated practice controls, local set and word totals, and the AI-generated set size preference into one organized Practice card. Files edited: `TingXieFlow/Views/SettingsDashboard.swift`, `AGENTS.md`.
- **2026-08-06**: Removed the standalone flag beside missed words in Vocabulary Hub rows while preserving red text, the Missed tag, and missed-word actions. Files edited: `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-08-06**: Increased overflow-menu padding and standardized 20-point right spacing across dictation-set and vocabulary ellipses, vertically aligned info-sheet guidance with its numbered markers, stabilized generated vocabulary editing with UUID-based row actions, rejected malformed AI vocabulary rows, and derived generated pinyin from the Chinese text. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `AGENTS.md`.
- **2026-07-24**: Implemented the expanded product TODO with missed-word-only learning actions, reusable information sheets, dynamic daily vocabulary, persisted speech and practice settings, AI-assisted set creation, edit menus, flip-card practice, dedicated missed-word review, full-shape tabs, and a floating set action. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/Services/AppPreferences.swift`, `TingXieFlow/Services/DictationStore.swift`, `TingXieFlow/Services/SpeechAudioEngine.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `TingXieFlow/Views/SettingsDashboard.swift`, `TODO.md`, `AGENTS.md`.
- **2026-07-23**: Improved sidebar drag responsiveness by keeping live width changes in memory, persisting only completed resizes, and reducing cursor updates to pointer enter and exit events. Files edited: `TingXieFlow/ContentView.swift`, `AGENTS.md`.
- **2026-07-23**: Added the native left-right resize cursor when hovering the custom persistent sidebar drag handle. Files edited: `TingXieFlow/ContentView.swift`, `AGENTS.md`.
- **2026-07-23**: Smoothed sidebar collapse and content transitions, persisted the user-selected sidebar width across navigation and launches, and added an accessible custom resize handle. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `AGENTS.md`.
- **2026-07-23**: Moved the sidebar collapse control to the top-right and replaced the fixed app shell with a native draggable horizontal split view supporting bounded sidebar resizing. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `AGENTS.md`.
- **2026-07-22**: Rebuilt the SwiftUI presentation around the supplied TingXieFlow design system with a dashboard-style dictation home, focused practice card, glassy set-creation sheet, card-based vocabulary catalog and inspector, refreshed settings landing, expanded palette tokens, and a labeled color-palette canvas preview. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-07-22**: Added a code-grounded product design guide covering hierarchy, screens, shipped scope, visual tokens, interactions, content, accessibility, reusable components, and implementation guardrails. Files edited: `design.md`, `AGENTS.md`.
- **2026-07-22**: Replaced stale high-level guidance with code-grounded product purpose, implemented workflow, architecture and critical-file map, technical constraints, visual tokens, canonical content terminology, non-features, and product goals. Files edited: `AGENTS.md`.
- **2026-07-21**: Added a 1.25-second pause between consecutive dictation word utterances while preserving immediate stop and word-jump behavior. Files edited: `TingXieFlow/Services/SpeechAudioEngine.swift`, `AGENTS.md`.
- **2026-07-21**: Added named, data-filled SwiftUI previews for Smart Dictation empty/list/practice states and Vocabulary Hub empty/populated states. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-07-21**: Corrected continuous dictation playback to advance through subsequent words, stop after the final word, continue forward after manual word selection, and repaired affected SwiftUI preview inputs. Files edited: `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-07-21**: Added looping word-level dictation playback with a stop/swap lifecycle and female Siri Mandarin default, refined sidebar/header/set spacing, and matched the Vocabulary Hub list and full-tab hit areas to the referenced Figma frame. Files edited: `TingXieFlow/Services/SpeechAudioEngine.swift`, `TingXieFlow/Views/SpeechTestView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-07-21**: Refined the Figma-matched navigation and workspace UI with a functional collapsible sidebar, larger icons and labels, correctly placed info/add controls, populated-set divider, persistent reveal behavior, immediate missed-word styling and persistence, and a rebuilt Vocabulary Hub search, tabs, alignment, and native table. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `AGENTS.md`.
- **2026-07-21**: Implemented the Figma-designed macOS app shell with a branded sidebar, dictation empty/list/practice states, interactive set creation, vocabulary search and MLX enrichment, settings dashboard, and background SwiftData mutations. Files edited: `TingXieFlow/ContentView.swift`, `TingXieFlow/TingXieFlowApp.swift`, `TingXieFlow/Views/TingXieTheme.swift`, `TingXieFlow/Views/SmartDictationView.swift`, `TingXieFlow/Views/VocabularyHubView.swift`, `TingXieFlow/Services/DictationStore.swift`, `AGENTS.md`.
- **2026-07-20**: Set Qwen generation temperature explicitly to 0.7 for more varied non-thinking responses. Files edited: `TingXieFlow/Services/LLM.swift`, `AGENTS.md`.
- **2026-07-20**: Disabled Qwen reasoning output and filtered residual `<think>` blocks from generated responses. Files edited: `TingXieFlow/Services/LLM.swift`, `AGENTS.md`.
- **2026-07-20**: Replaced the external Ollama HTTP dependency with in-process MLX Swift inference using a cached Qwen 3 0.6B 4-bit model and updated the LLM test interface. Files edited: `TingXieFlow.xcodeproj/project.pbxproj`, `TingXieFlow/Services/LLM.swift`, `TingXieFlow/Views/LLMTestView.swift`, `AGENTS.md`.
- **2026-07-20**: Added an interactive local Ollama test view with editable prompts, response and error states, and async generation; modernized the LLM helper to use async/await with HTTP error handling. Files edited: `TingXieFlow/Views/LLMTestView.swift`, `TingXieFlow/Services/LLM.swift`, `AGENTS.md`.
- **2026-07-14**: Fixed Swift 6 actor isolation for Ollama request/response DTOs and disabled Ollama response streaming for single-response decoding. Files edited: `TingXieFlow/Services/LLM.swift`, `AGENTS.md`.
- **2026-07-14**: Refined speech testing to use a curated natural Chinese voice list and removed accent-grouped voice selection. Files edited: `TingXieFlow/Services/SpeechAudioEngine.swift`, `TingXieFlow/Views/SpeechTestView.swift`, `AGENTS.md`.
- **2026-07-14**: Added native speech scratchpad UI with Mandarin voice selection, speed/pitch sliders, and playback controls. Files edited: `TingXieFlow/Views/SpeechTestView.swift`, `AGENTS.md`.
- **2026-07-10**: Initialized native macOS Xcode project skeleton with SwiftData storage containers. Authenticated Git control origins to GitHub remote repository.
