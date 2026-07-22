# AGENTS.md

## Product Purpose

- **Product name:** **TingXieFlow**. There is currently no repository README or separate tagline; use the product name and in-app copy as the canonical language.
- **Audience:** Chinese learners, including foreign-language learners and elementary through early middle-school students.
- **Primary job:** Turn user-authored Chinese vocabulary sets into an audio-first **Smart Dictation** practice loop. A learner creates a set, listens to its words in sequence, reveals the characters, and marks difficult words as **Missed**.
- **Supporting job:** Collect every saved item in **Your Vocabulary Hub**, where learners can search by Chinese, pinyin, or set tag; filter **All Words**, **Missed Words**, and **Idioms**; inspect translations; mark missed words as learned; and generate a short contextual sentence.
- **Privacy model:** Vocabulary and practice state persist locally with SwiftData. Sentence generation runs in-process with Qwen 3 0.6B 4-bit through MLX; the model is downloaded from Hugging Face once and cached locally. There is no application backend.
- **Audio model:** Dictation uses `AVSpeechSynthesizer`, prefers the installed Mandarin voices Yu-shu, Tingting, and Li-Mu, defaults to a female Siri voice when available, and inserts a 1.25-second post-utterance pause.

## Current Product Shape

Smart Dictation is the dominant workflow and should receive the greatest visual and product weight:

1. **Create New Set:** Parse one item per line in the form `Chinese | pinyin | translation`. Four-character entries are currently classified as idioms.
2. **Practice:** Play a set continuously or jump to a tapped word. Before reveal, the flow layout shows pinyin; after **Reveal Characters**, it shows hanzi and enables **Mark Missed** and **Finish Set**.
3. **Review:** Missed state is saved in the background and feeds both the practice filters and Vocabulary Hub.
4. **Enrich:** The Vocabulary Hub inspector asks the local model for one natural, short, modern Chinese example sentence and saves the result on the word.

Do not present planned or historical ideas as shipped features. In particular, the codebase does **not** currently implement Anki export, audio-file packaging, automatic idiom character breakdown generation, emotion tags, Ollama, or a cloud sync/backend.

## Architecture and Critical Files

- `TingXieFlow/TingXieFlowApp.swift`: App entry point, persistent `ModelContainer`, registered SwiftData schema, window defaults, and scene setup.
- `TingXieFlow/ContentView.swift`: Root desktop shell. Owns navigation state and the collapsible 266/64-point sidebar, routes among **Smart Dictation**, **Your Vocabulary Hub**, and **Settings**, and presents set creation.
- `TingXieFlow/Views/SmartDictationView.swift`: Primary feature and source of truth for empty, set-list, and practice states; set-input parsing; playback progression; character reveal; and missed-word interaction.
- `TingXieFlow/Views/VocabularyHubView.swift`: Search/filter table, word inspector, contextual-sentence generation, learned-state action, and Settings dashboard.
- `TingXieFlow/Views/TingXieTheme.swift`: Shared visual identity and reusable shell components, including `TingXiePalette`, `AppSidebar`, `WorkspaceHeader`, and `GreenCapsuleButtonStyle`.
- `TingXieFlow/Models/DictationSet.swift`: Named, dated practice set with a cascade relationship to its vocabulary words.
- `TingXieFlow/Models/VocabularyWord.swift`: Canonical vocabulary record: Chinese, English translation, pinyin, missed/idiom flags, optional generated sentence/breakdown, tags, and owning set.
- `TingXieFlow/Services/DictationStore.swift`: `@ModelActor` boundary for creating sets and persisting missed or generated-sentence state away from direct view mutation.
- `TingXieFlow/Services/SpeechAudioEngine.swift`: Observable Apple TTS adapter, preferred voices, speed/pitch values, stop behavior, inter-word pause, and completion callback.
- `TingXieFlow/Services/LLM.swift`: Actor-isolated MLX/Qwen session loading, Hugging Face download/tokenizer adapters, generation parameters, and residual `<think>` removal.
- `TingXieFlow/Views/SpeechTestView.swift` and `TingXieFlow/Views/LLMTestView.swift`: Settings-accessible diagnostic playgrounds for the two local engines; they are not primary navigation destinations.
- `TingXieFlow.xcodeproj/project.pbxproj`: Target configuration and package dependencies (`mlx-swift-lm`, `swift-huggingface`, and `swift-transformers`). Ask before changing deployment targets or build settings.
- `TingXieFlow/Item.swift`: Unused starter SwiftData model still registered in the schema; do not treat it as product-domain data.

## Technical Constraints

- The current experience is a native SwiftUI desktop interface built around `HStack`/`HSplitView`, with a minimum window of 900 × 650 and a default of 1024 × 768.
- Local persistence is SwiftData only. Keep the `DictationSet` → `VocabularyWord` cascade and inverse session relationship intact.
- SwiftData writes from feature views go through `DictationStore`, whose `@ModelActor` owns its model context.
- Local generation is serialized by `LocalLanguageModel` and cached in one `ChatSession`. Preserve explicit async/await and keep model loading/generation from blocking interaction.
- The app sandbox permits outgoing network access because first use may need to download the model; normal generation is local after caching.
- Use SF Symbols for interface iconography and native SwiftUI controls unless the established custom component already covers the need.

## Visual Identity and Content Rules

- **Product structure:** A dark-green branded sidebar beside a pale-green workspace. Within Vocabulary Hub, use a two-pane catalog/inspector shape; within Smart Dictation, use a set list leading into a focused sequential practice state.
- **Canonical colors (`TingXiePalette`):** sidebar `#296124`; workspace `#BAD9B7`; surface `#ECF7EB`; accent `#276525`; word-of-day yellow `#FDFBA7`; missed/error red `#C41F23`; alternating table stripe derived from `#A5C6A2` at 40% opacity.
- **Type hierarchy:** 40-point bold workspace titles, 32-point bold product name, 24-point set titles, 44-point bold inspected Chinese word, and 14-point semibold sidebar labels. Preserve this hierarchy before introducing new sizes.
- **Geometry:** Existing corner radii are predominantly 8 points (cards, selections, search, table, tags) and 12 points for Settings cards. Primary green actions use 40-point-tall capsules. Workspace headers are 112 points high with 40-point horizontal content padding.
- **Canonical labels:** Use the exact in-app terms **Smart Dictation**, **Your Vocabulary Hub**, **Create New Set**, **All Words**, **Missed Words**, **Idioms**, **Reveal Characters**, **Mark Missed**, **Finish Set**, **Contextual Sentences**, **Mark As Learned**, **Speech & Pronunciation**, and **Local Language Model**.
- Start designs with real checked-in content such as `HSK 5 full set`, `Everyday idioms`, `把握`, `集中`, `核心`, `反复`, and `莫名其妙`. Do not invent testimonials, usage metrics, pricing, integrations, feature claims, or placeholder marketing copy.
- Support Light and Dark appearance by preferring semantic foreground/background styles where the palette does not intentionally establish brand color.

## Product Goals

1. Make the listen → reveal → self-assess loop fast, predictable, and keyboard/mouse accessible.
2. Preserve learning continuity: set membership, missed status, searchability, and generated examples should survive relaunches.
3. Keep speech and language-model work private and local after required model/voice assets are installed.
4. Keep views modular and reusable while maintaining one clear source of truth for palette, persistence mutations, speech, and generation.
5. Treat Smart Dictation as the lead experience; supporting settings and diagnostics should not compete with practice and review.

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
- Use explicit async/await patterns for local model loading and generation so the interface stays responsive.
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
