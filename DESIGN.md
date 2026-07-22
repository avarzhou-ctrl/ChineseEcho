# TingXieFlow Design Guide

## Source of Truth

This guide describes the product currently implemented in the repository. The project has no README or checked-in marketing site, so product names, labels, content, behavior, and visual rules come from the SwiftUI views, models, services, previews, and Xcode configuration.

When this document and the application disagree, the current implementation is authoritative. Update both in the same change when intentionally evolving the design.

## Product Definition

**TingXieFlow** is a native Chinese-learning app built around audio-first dictation practice.

Its primary loop is:

1. Create a vocabulary set from Chinese, pinyin, and translation entries.
2. Listen to each Chinese word through native Apple speech synthesis.
3. Reveal the written characters after listening.
4. Mark difficult items as **Missed**.
5. Review saved vocabulary and generate a contextual sentence locally.

The primary audience is Chinese learners, including foreign-language learners and elementary through early middle-school students. The experience should feel focused, supportive, and easy to scan without making the practice feel childish.

### Product hierarchy

1. **Smart Dictation** is the lead experience.
2. **Your Vocabulary Hub** supports review and enrichment after practice.
3. **Settings** exposes speech and local-language-model diagnostics.

Settings and technical model details must not compete visually with the practice loop.

### Current scope

The shipped design may represent:

- User-created dictation sets
- Continuous or word-selected audio playback
- Pinyin-first practice and character reveal
- All-word, missed-word, and idiom filters
- Search by Chinese, pinyin, or set tag
- English translations
- Locally generated contextual sentences
- Speech voice, speed, and pitch controls
- Local SwiftData persistence

Do not present Anki export, audio-file packaging, cloud sync, Ollama, emotion tags, or automatic idiom character breakdowns as available features. They are not implemented.

## Experience Principles

### Listening comes first

The practice state should withhold Chinese characters until the learner explicitly chooses **Reveal Characters**. Pinyin provides orientation without replacing the listening task.

### One clear next action

Each state needs an obvious primary action:

- Empty state: **Create New Set**
- Practice before playback: **Play Dictation Audio Continuously**
- Practice before reveal: **Reveal Characters**
- Practice after reveal: **Mark Missed** or **Finish Set**
- Vocabulary detail: regenerate a contextual sentence or **Mark As Learned**

### Calm progress, visible consequences

Playback progress should be legible without creating urgency. Marking a word missed should update its red visual state immediately, then persist in the background.

### Private by default

Vocabulary and practice state remain in SwiftData. Sentence generation runs in-process with Qwen through MLX after the model is downloaded and cached. Product copy should say “local” or “on this Mac” where technical context is useful, but should not turn privacy architecture into the main learning experience.

## Information Architecture

The app uses a persistent branded sidebar and a single main workspace.

| Destination | Purpose | Primary content |
| --- | --- | --- |
| Smart Dictation | Create and practice vocabulary sets | Empty state, dated set list, active practice session |
| Your Vocabulary Hub | Search and revisit saved words | Filtered vocabulary list and word inspector |
| Settings | Test supporting engines | Speech & Pronunciation and Local Language Model cards |

An active dictation set appears beneath **Smart Dictation** in the expanded sidebar. The sidebar may collapse from 266 points to 64 points; symbols and help text must preserve navigation clarity in both forms.

## Screen Specifications

### App shell

- Default window: 1024 × 768 points
- Minimum window: 900 × 650 points
- Expanded sidebar: 266 points
- Collapsed sidebar: 64 points
- Workspace fills all remaining space
- Window uses a hidden title bar
- Sidebar collapse animation: ease-in-out over 0.18 seconds

The shell is implemented in `TingXieFlow/ContentView.swift`. Shared sidebar and header elements live in `TingXieFlow/Views/TingXieTheme.swift`.

### Sidebar

The expanded sidebar contains:

1. Product name: **TingXieFlow**
2. Word-of-the-day card: **上午**, **Morning**, **WORD OF THE DAY**
3. **Smart Dictation**
4. Active set title when applicable
5. **Your Vocabulary Hub**
6. Flexible space
7. **Settings**

Use SF Symbols already established by the app:

- Smart Dictation: `waveform.badge.microphone`
- Vocabulary Hub: `character.book.closed.fill`
- Settings: `gearshape.fill`
- Collapse/expand: `sidebar.left` / `sidebar.right`

### Smart Dictation home

The workspace header reads **Smart Dictation**.

When no sets exist, center the microphone symbol and show:

- **No Sessions Yet**
- “Create your first custom practice round to start testing your vocabulary.”
- **Create New Set**

When sets exist, replace the empty state with a vertically divided list. Each row shows a green play symbol, the set title, and its creation date. Keep the newest set first.

### Create New Set sheet

Use a 560 × 440-point modal with:

- **Create New Set** title
- **Set name** field
- **Words** editor
- Instruction: “Enter one item per line: Chinese | pinyin | translation”
- **Cancel** and **Create** actions

Use checked-in sample content when a populated state is required:

```text
HSK 5 full set
把握 | bǎ wò | grasp
比例 | bǐ lì | proportion
核心 | hé xīn | core
必然 | bì rán | inevitable
反复 | fǎn fù | repeatedly
集中 | jí zhōng | concentrate
深刻 | shēn kè | profound
莫名其妙 | mò míng qí miào | baffling
```

The implementation currently classifies any four-character entry as an idiom. Designs should expose the resulting **Idiom** state but should not imply linguistic validation.

### Practice session

The active set title replaces the generic workspace title. Below it, show a segmented filter with:

- **All Words**
- **Missed Words**
- **Idioms**

The practice card contains:

1. A wrapping word field on the pale surface color
2. Pinyin before reveal and Chinese characters after reveal
3. Bold styling for the current word
4. Red styling for revealed missed words
5. A progress bar
6. One play/stop control
7. Reveal and completion actions

Playback proceeds through the filtered list and stops after its final item. Selecting a word moves playback to that position and continues forward. A 1.25-second post-utterance pause separates entries.

If a filter has no matches, use **No Words in This Filter** with “Choose a different category to continue practicing.”

### Your Vocabulary Hub

Use a two-pane `HSplitView` because the product data naturally forms a catalog and inspector:

- Left pane: minimum 430 points, ideal 490 points
- Right inspector: minimum 260 points, ideal 310 points

The left pane contains:

1. **Your Vocabulary Hub** header
2. Search field: **Search vocabulary, pinyin, tags...**
3. Three full-width filter tabs: **All Words**, **Missed Words**, **Idioms**
4. Alternating-row vocabulary list showing Chinese, pinyin, and tags

The inspector contains:

- Chinese word at high visual prominence
- Pinyin
- **Idiom**, **Missed**, and set-name tags when applicable
- English translation or **No translation yet**
- **Contextual Sentences**
- Regenerate control
- Generated sentence or the existing generation prompt text
- **Missed** status
- **Mark As Learned**

When no vocabulary exists, show **No Vocabulary Yet** and “Words from your dictation sets will appear here.”

### Settings

Settings uses large linked cards for:

- **Speech & Pronunciation** — “Choose a Mandarin voice and adjust dictation speed and pitch.”
- **Local Language Model** — “Test Qwen generation running privately on this Mac with MLX.”

The destination screens are diagnostic playgrounds. Preserve native GroupBox, Picker, Slider, and Button behavior instead of turning them into branded marketing panels.

## Visual System

### Color

Colors are defined in `TingXieFlow/Views/TingXieTheme.swift`.

| Token | Value | Use |
| --- | --- | --- |
| `sidebar` | `#296124` | Persistent navigation background |
| `sidebarSelection` | `#72AE6C` at 40% | Selected navigation and word-of-day card |
| `workspace` | `#BAD9B7` | Main workspace background |
| `surface` | `#ECF7EB` | Cards, search, tables, and practice field |
| `accent` | `#276525` | Titles, controls, progress, and primary actions |
| `wordOfDay` | `#FDFBA7` | Word-of-day eyebrow text |
| `missed` | `#C41F23` | Missed state, destructive emphasis, and errors |
| `tableStripe` | `#A5C6A2` at 40% | Alternating vocabulary rows |

Do not add decorative colors without a semantic need. Use semantic SwiftUI foreground styles for primary and secondary text so the app remains readable in Light and Dark appearance.

### Typography

Use the system typeface and preserve the existing hierarchy.

| Role | Style |
| --- | --- |
| Workspace title | 40 pt, bold, accent color |
| Product name | 32 pt, bold, white |
| Inspected Chinese word | 44 pt, bold |
| Word-of-day Chinese | 48 pt, bold |
| Word-of-day translation | 30 pt, medium |
| Set list title | 24 pt, medium |
| Sidebar label | 14 pt, semibold |
| Vocabulary row | 16 pt, regular |
| Tag | 8 pt compact / 10 pt regular, medium |

Chinese characters, pinyin tone marks, and English translations must remain selectable or legible at their intended scale. Do not uppercase Chinese or pinyin.

### Spacing and geometry

- Workspace header: 112 points high
- Header title inset: 40 points horizontally and 42 points from the top
- Header utility inset: 24 points from top and trailing edge
- Standard workspace side inset: 24 or 32 points depending on density
- Standard compact spacing: 8 points
- Settings-card spacing: 16 points
- Practice flow spacing: 18 points
- Common corner radius: 8 points
- Settings-card corner radius: 12 points
- Primary capsule height: 40 points
- Sidebar navigation row: 44 points high

Prefer these established values before adding new spacing or radius tokens.

### Iconography

Use `Image(systemName:)` exclusively for interface icons. Match the existing filled, legible symbols and include accessibility labels for icon-only actions. Avoid custom illustrations when an SF Symbol already expresses the action.

## Reusable Components

New work should compose or extend these existing elements before creating parallel variants:

- `AppSidebar`
- `SidebarButton`
- `WorkspaceHeader`
- `GreenCapsuleButtonStyle`
- `WordTags`
- `TagLabel`
- `SettingsCard`
- `FlowLayout`

Keep visual tokens in `TingXiePalette`. A new shared size or spacing value belongs beside the theme only when it is repeated across multiple features.

## Interaction and State

### Playback

- Play and stop use one swapping icon control.
- Stop must be immediate.
- Changing the selected word stops the current utterance before starting the new one.
- Changing filters resets to the first matching word and restarts only if continuous playback is already active.
- Completion after the final word returns the play control to its inactive state.

### Reveal and missed state

- Character reveal remains active for the rest of the open practice session.
- **Mark Missed** applies to the current word.
- The missed color appears optimistically while persistence completes.
- **Mark As Learned** is disabled unless the inspected word is missed.

### Loading and errors

- Disable sentence regeneration while generation is active.
- Show a compact progress indicator in place of the regeneration icon.
- Keep generation errors near **Contextual Sentences** and use the missed/error red.
- The first model use may require a download. The diagnostic screen should retain its explicit connection error language.

## Content Style

- Use the exact product labels already present in the interface.
- Prefer direct action verbs: **Create**, **Reveal**, **Mark**, **Finish**, **Generate**.
- Keep instructional text brief and concrete.
- Preserve the distinction between a **set**, a **session**, a **word**, an **idiom**, and a **missed word**.
- Use real vocabulary from code previews and the set-creation defaults in mockups.
- Do not invent user counts, scores, streaks, achievements, testimonials, plans, prices, integrations, or success metrics.
- Do not add a tagline unless one becomes part of the repository’s canonical product copy.

## Accessibility

- Maintain text and control contrast across Light and Dark appearance.
- Never communicate missed state with red alone; pair it with **Missed**, `flag.fill`, or another textual/symbolic cue.
- Give every icon-only control an accessibility label and help text where appropriate.
- Preserve full-row hit targets in navigation, filters, and vocabulary lists.
- Respect the window minimums so split-pane content does not collapse below readable widths.
- Keep native focus, keyboard shortcuts, Picker behavior, and control states unless a custom interaction offers equivalent accessibility.
- Combine the word-of-the-day card into one meaningful accessibility element rather than exposing decorative fragments.

## Implementation Guardrails

- Keep Smart Dictation visually dominant.
- Keep the app native to SwiftUI and SF Symbols.
- Route feature persistence mutations through `DictationStore` rather than mutating SwiftData models directly from views.
- Keep speech behavior in `SpeechAudioEngine` and model behavior in `LocalLanguageModel`.
- Preserve async/await around local model loading and generation.
- Do not change deployment targets or Xcode build settings without approval.
- Add named, data-filled SwiftUI previews for material new states.
- Update this guide when a change alters navigation, canonical copy, tokens, shared components, or the core learning loop.

## File Map

| Area | Source |
| --- | --- |
| App lifecycle and schema | `TingXieFlow/TingXieFlowApp.swift` |
| Root navigation shell | `TingXieFlow/ContentView.swift` |
| Theme and shared shell UI | `TingXieFlow/Views/TingXieTheme.swift` |
| Dictation workflow | `TingXieFlow/Views/SmartDictationView.swift` |
| Vocabulary review and Settings | `TingXieFlow/Views/VocabularyHubView.swift` |
| Speech diagnostic UI | `TingXieFlow/Views/SpeechTestView.swift` |
| Local-model diagnostic UI | `TingXieFlow/Views/LLMTestView.swift` |
| Set and word models | `TingXieFlow/Models/DictationSet.swift`, `TingXieFlow/Models/VocabularyWord.swift` |
| Background persistence | `TingXieFlow/Services/DictationStore.swift` |
| Native speech | `TingXieFlow/Services/SpeechAudioEngine.swift` |
| Local generation | `TingXieFlow/Services/LLM.swift` |
| Dependencies and build configuration | `TingXieFlow.xcodeproj/project.pbxproj` |
