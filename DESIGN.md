# ChineseEcho Design Guide

## Source of Truth

This guide describes the product currently implemented in the repository. The project has no README or checked-in marketing site, so product names, labels, content, behavior, and visual rules come from the SwiftUI views, models, services, previews, and Xcode configuration.

When this document and the application disagree, the current implementation is authoritative. Update both in the same change when intentionally evolving the design.

## Product Definition

**ChineseEcho** is a native Chinese-learning app built around audio-first dictation practice.

Its primary loop is:

1. Create a vocabulary set from Chinese, pinyin, and translation entries.
2. Listen to each Chinese word through native Apple speech synthesis.
3. Reveal the written characters after listening.
4. Mark difficult items as **Missed**.
5. Review saved vocabulary and generate a contextual sentence locally.

The primary audience is Chinese learners, including foreign-language learners and elementary through early middle-school students. The experience should feel focused, supportive, and easy to scan without making the practice feel childish.

### Product hierarchy

1. **Smart Dictation** is the lead experience.
2. **Vocabulary** supports review and enrichment after practice.
3. **Settings** exposes speech and local-language-model diagnostics.

Settings and technical model details must not compete visually with the practice loop.

### Current scope

The shipped design may represent:

- User-created dictation sets
- Continuous or word-selected audio playback
- Pinyin-first practice and character reveal
- All-word, missed-word, and idiom filters
- A scheduled cross-set due-review queue
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

Vocabulary, review scheduling, and practice state remain in SwiftData. The active practice queue is checkpointed locally after meaningful changes so the exact set or cross-set due-review source, card order, current card, and completed grading can resume when that practice source is reopened, while every fresh launch remains anchored on Smart Dictation home. Versioned JSON backups include the full learning library, enrichment, hints, missed-word state, review dates, analytics, and any interrupted session; imports are validated and previewed before replacing local data. On first launch, ChineseEcho presents Getting Started before requesting notification permission through the native macOS dialog; accepted reminders keep one notification scheduled for the earliest due review. Due reminders request the native macOS banner and sound presentation even while ChineseEcho is active, while the learner's System Settings retain final control over notification visibility and style. Sentence generation runs in-process with Qwen through MLX after the learner explicitly chooses the optional download or selects an AI generation action. Product copy should say “local” or “on this Mac” where technical context is useful, but should not turn privacy architecture into the main learning experience.

## Information Architecture

The app uses a custom horizontal split shell with a branded sidebar and a single main workspace. The interface uses the original ChineseEcho palette, tonal cards, solid controls, and restrained system materials.

| Destination | Purpose | Primary content |
| --- | --- | --- |
| Smart Dictation | Create, practice, and revisit vocabulary sets | Due-review card, dated set list, active practice session |
| Vocabulary | Search and revisit saved words | Filtered vocabulary list and word inspector |
| Settings | Test supporting engines | Speech & Pronunciation and Local Language Model cards |

An active dictation set appears beneath **Smart Dictation** in the sidebar. The sidebar may be resized from 220 to 420 points, collapsed to 64 points, and remembers its expanded width.

## Screen Specifications

### App shell

Fresh windows open on Smart Dictation home even when an interrupted practice checkpoint exists. The checkpoint remains available and resumes only after the learner manually reopens its set or Due Review source.

On a true first run, a versioned **Getting Started** spotlight tour runs over the real interface and automatically moves through Smart Dictation, Vocabulary, and Settings. Its solid pale-green card surface remains consistent with the app's tonal cards over the dimmed backdrop, which extends through the hidden macOS title bar for one continuous window treatment. Spotlight cutouts highlight the sidebar destinations, floating create-set button, vocabulary filters, and voice-preview control and block accidental interaction with the underlying library. The final step defaults to **Download Local AI** while requiring the learner to finish setup before download begins; **Not Now** keeps speech, manual set creation, practice, grading, and review fully usable. A learner may skip the feature tour directly to the required Local AI choice, step backward or forward with chevrons, and replay or close the tour from Settings. Spotlight and page transitions respect Reduce Motion.

- Default window: 1180 × 720 points
- Minimum window: 900 × 650 points
- Sidebar: 220–420 points, with a 266-point ideal width
- Workspace fills all remaining space
- Window uses the original hidden-title-bar presentation
- A custom accessible resize handle manages the persistent sidebar width
- Branded colors and tonal surfaces remain visually stable during live resizing

The shell is implemented in `ChineseEcho/ContentView.swift`. Shared sidebar and header elements live in `ChineseEcho/Views/TingXieTheme.swift`.

### Sidebar

The sidebar contains:

1. Product name: **ChineseEcho**
2. **Smart Dictation**
3. Active set title when applicable
4. **Vocabulary**
5. **Settings**
6. Flexible space
7. Word-of-the-day card, sourced from saved vocabulary

Use SF Symbols already established by the app:

- Smart Dictation: `waveform.badge.microphone`
- Vocabulary Hub: `character.book.closed.fill`
- Settings: `gearshape.fill`
- Collapse/expand: native macOS sidebar control

### Smart Dictation home

The workspace header reads **Smart Dictation**.

When no sets exist, center the microphone symbol and show:

- **No Sessions Yet**
- “Create your first custom practice round to start testing your vocabulary.”
- **Create New Set**

When sets exist, replace the empty state with a vertically divided list. Each row shows the set's chosen SF Symbol or emoji on its selected accent-color treatment, the set title, and its creation date. Keep the newest set first. Reuse the same appearance in search results and beside the active practice-set title.

Keep Word of the Day in the sidebar. Above **Recent Dictation Practice**, show a compact **Due Review** card. When words are due, elevate the card with an accent outline, filled icon, due-now badge, and **Start Review** action. Bold the dynamic word count or relative next-review time within its supporting sentence. When the learner is caught up, collapse it into a quieter status row showing the next scheduled review; before any word has been graded, explain that normal dictation practice starts the schedule. Use an explicitly pale-green gradient for the introductory listening-drills hero rather than a neutral gray surface.

### Create New Set sheet

Use the split create-set editor with:

- **Create New Set** title
- **Set name** field with a customizable set icon control
- A compact picker offering curated SF Symbols, emoji, and accessible accent colors; reuse it when editing a set
- **Fill with Local AI** field accepting Chinese words separated by commas, spaces, or new lines
- **Fill Details** action that preserves the supplied words and fills in pinyin and concise English translations
- Selectable **Model Output** panel showing the initial response and any repair response, with a Copy action
- Editable generated rows for review, reordering, and correction
- Manual import using “Chinese | pinyin | translation” lines
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

Words may include a short optional learner hint. The listening side exposes a **Show Hint** action only when a hint exists; the hint remains concealed until requested and does not reveal the answer.

Grading the final card opens a session summary automatically. **Finish Set** opens the same summary early with partial-session progress. The summary reports current-session accuracy, learned words, and missed words, and can start a follow-up queue containing only the words missed in that run.

Playback proceeds through the filtered list and stops after its final item. Selecting a word moves playback to that position and continues forward. A 1.25-second post-utterance pause separates entries.

If a filter has no matches, use **No Words in This Filter** with “Choose a different category to continue practicing.”

### Due review

Every Known or Missed grading decision schedules that saved vocabulary record independently. A first Known result uses the second timing interval; a Missed result uses the shortest interval. The default Standard schedule waits 1, 3, 7, 14, and 30 days as the learner repeatedly marks a word Known. Untouched words remain unscheduled.

The Due Review card's trailing ellipsis exposes More Often, Standard, and Less Often presets plus an exact-timing editor. The editor labels waits by visible learning outcomes—After Missed, After first Known, and subsequent Known results—rather than exposing the underlying box numbers. Custom intervals must increase and remain between 1 and 365 days. Frequency changes apply the next time a word is graded; existing review dates remain stable so active queues, Undo snapshots, and notifications are not silently rewritten. The selected preset and custom intervals persist locally and travel with versioned backups.

Starting **Due Review** opens the same immersive listening and grading interface with a snapshot of all currently due words across sets, ordered most overdue first. The set filter is hidden, the footer reads **Finish Review**, and completion reads **Review Complete**. Grading from any practice mode updates the schedule, Undo restores the previous schedule, and an interrupted due-review queue resumes exactly after relaunch.

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

Settings uses a centered single-column sequence of compact grouped lists in this order:

1. **Getting Started**
   - Replay Tutorial
2. **Speech & Pronunciation**
3. **Local AI**
4. **Practice**
5. **Local Backup**

Each group uses a simple icon-and-title header and separator. Pickers, sliders, toggles, and steppers retain native macOS interaction, while actions use the shared ChineseEcho semantic button styles.

Review notification consent does not appear in Settings or in a custom in-app banner. On first launch, present Getting Started first, then use only the native macOS notification-permission dialog; after the learner responds, macOS retains that choice in System Settings.

## Visual System

### Color

Colors are defined in `ChineseEcho/Views/TingXieTheme.swift`.

| Token | Value | Use |
| --- | --- | --- |
| `sidebar` | `#296124` | Persistent navigation background |
| `sidebarSelection` | `#72AE6C` at 40% | Selected navigation and word-of-day card |
| `workspace` | `#EBFFE6` | Main workspace background |
| `surface` | `#ECF7EB` | Cards, search, tables, and practice field |
| `accent` | `#0E490E` | Titles, controls, progress, and primary actions |
| `wordOfDay` | `#FDFBA7` | Word-of-day eyebrow text |
| `missed` | `#C41F23` | Missed state, destructive emphasis, and errors |
| `tableStripe` | `#A5C6A2` at 40% | Alternating vocabulary rows |

Structural tokens retain the original fixed ChineseEcho green palette in every appearance. Primary actions use solid accent fills, secondary actions use subtle tonal fills and outlines, search and filter controls use opaque palette surfaces, and content cards use the established light material treatment.

Do not add decorative colors without a semantic need. Use semantic SwiftUI foreground styles for primary and secondary text so the app remains readable in Light and Dark appearance.

### Typography

Use the system typeface and preserve the existing hierarchy.

| Role | Style |
| --- | --- |
| Workspace title | 40 pt, bold, accent color |
| Product name | 30 pt, bold, adaptive foreground |
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
- Compact, control, card, and prominent-card radii: 9, 12, 14, and 16 points
- Compact, regular, and prominent action heights: 32, 40, and 56 points
- Standard field height: 44 points
- Standard sheet header and footer heights: 70 and 76 points
- Sidebar navigation row: 44 points high

Prefer these established values before adding new spacing or radius tokens.

### Iconography

Use `Image(systemName:)` exclusively for interface icons. Match the existing filled, legible symbols and include accessibility labels for icon-only actions. Avoid custom illustrations when an SF Symbol already expresses the action.

## Reusable Components

New work should compose or extend these existing elements before creating parallel variants:

- `TingXieControlMetrics`
- `TingXieButtonStyle`
- `TingXieInputSurfaceModifier`
- `TingXieSheetBarModifier`
- `TonalCardModifier`
- `AppSidebar`
- `SidebarButton`
- `WorkspaceHeader`
- `SearchField`
- `SlidingFilterBar`
- `WordTags`
- `TagLabel`
- `SettingsCard`
- `FlowLayout`

Keep visual tokens in `TingXiePalette`. A new shared size or spacing value belongs beside the theme only when it is repeated across multiple features.

### Controls

Use semantic roles rather than choosing a style page by page:

- **Primary**: solid accent capsule for the single clearest next action in a group.
- **Secondary**: accent outline for alternate actions with equal control geometry.
- **Quiet**: borderless accent treatment for dismissals, toolbar utilities, and low-emphasis actions.
- **Destructive**: red outline and label for irreversible or removal actions.
- **Icon-only**: use the same semantic variants with a square hit target that resolves to a circular capsule; always include an accessibility label and help text.

Disabled controls retain their semantic color at reduced opacity, and pressed controls use a restrained tonal response. Use compact sizing in dense cards and toolbars, regular sizing in sheets and primary workflows, and prominent sizing only for floating creation actions. Text fields and text editors outside native grouped forms use the shared inset input surface. Modal editors use the shared header and footer geometry.

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

- Use motion-aware jade skeletons while SwiftData readiness, practice queues, vocabulary enrichment, contextual sentences, or model-storage metadata are genuinely pending.
- Mirror the final page geometry so loading does not cause large layout jumps, and never treat a genuinely empty library as loading.
- Hide decorative skeleton fragments from assistive technologies, expose one meaningful loading label per region, and replace shimmer with a static placeholder under Reduce Motion.
- Disable sentence regeneration while generation is active and show two sentence-card skeletons below its compact progress action.
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
| App lifecycle and schema | `ChineseEcho/ChineseEchoApp.swift` |
| Root navigation shell | `ChineseEcho/ContentView.swift` |
| Theme and shared shell UI | `ChineseEcho/Views/TingXieTheme.swift` |
| First-run guidance | `ChineseEcho/Views/FirstRunTutorialView.swift` |
| Skeleton loading system | `ChineseEcho/Views/SkeletonLoadingView.swift` |
| Dictation workflow | `ChineseEcho/Views/SmartDictationView.swift` |
| Vocabulary review and Settings | `ChineseEcho/Views/VocabularyHubView.swift` |
| Speech diagnostic UI | `ChineseEcho/Views/SpeechTestView.swift` |
| Local-model diagnostic UI | `ChineseEcho/Views/LLMTestView.swift` |
| Set and word models | `ChineseEcho/Models/DictationSet.swift`, `ChineseEcho/Models/VocabularyWord.swift` |
| Background persistence | `ChineseEcho/Services/DictationStore.swift` |
| Review scheduling | `ChineseEcho/Services/ReviewScheduler.swift` |
| Review notifications | `ChineseEcho/Services/ReviewNotificationScheduler.swift` |
| Native speech | `ChineseEcho/Services/SpeechAudioEngine.swift` |
| Local generation | `ChineseEcho/Services/LLM.swift` |
| Dependencies and build configuration | `ChineseEcho.xcodeproj/project.pbxproj` |
