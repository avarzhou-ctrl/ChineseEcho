# ChineseEcho

[![Release](https://img.shields.io/github/v/release/avarzhou-ctrl/ChineseEcho?label=release&color=0E490E)](https://github.com/avarzhou-ctrl/ChineseEcho/releases/latest)
![macOS 15.6+](https://img.shields.io/badge/macOS-15.6%2B-000000?logo=apple&logoColor=white)
![Apple silicon](https://img.shields.io/badge/architecture-Apple%20silicon-0E490E)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0D96F6?logo=swift&logoColor=white)

**Listen. Learn. Remember.**

ChineseEcho is a native macOS app for practicing Chinese dictation, organizing
vocabulary, reviewing missed words, and generating contextual examples with an
optional on-device language model.

[Download ChineseEcho 1.0](https://github.com/avarzhou-ctrl/ChineseEcho/releases/tag/v1.0)
· [Website](https://avarzhou-ctrl.github.io/ChineseEcho/)
· [Support](https://avarzhou-ctrl.github.io/ChineseEcho/support/)

## Features

- **Smart Dictation** with native macOS Mandarin speech
- **Continuous Dictation** for paper-based listening and writing practice
- **Vocabulary Review** with configurable card layouts and learner hints
- **Due Reviews** using locally stored five-box scheduling
- **Vocabulary Library** for words, meanings, pinyin, tags, idioms, and examples
- **Optional Local AI** for private on-device vocabulary details and bilingual examples
- **Mainland and Taiwanese Mandarin** voices with adjustable speed, pitch, and pauses
- **Local backup and restore** using portable JSON files

## Requirements

- Apple silicon Mac (M1 or newer)
- macOS 15.6 or later
- Approximately 2.5 GB of free storage for the optional Local AI model
- Internet access only when downloading the optional model

## Install the current release

ChineseEcho 1.0 is distributed as a free, unsigned direct download.

1. Download `ChineseEcho-1.0-macOS.zip` from the
   [v1.0 release](https://github.com/avarzhou-ctrl/ChineseEcho/releases/tag/v1.0).
2. Unzip it and drag `ChineseEcho.app` to **Applications**.
3. Try to open ChineseEcho once. macOS will block the unsigned app.
4. Open **System Settings → Privacy & Security** and select **Open Anyway**.
5. Enter your Mac login password if requested, then open ChineseEcho again.

Download only from the official release page. The release includes a SHA-256
checksum file and verification instructions.

## Privacy

Vocabulary, practice history, review schedules, generated examples, and
preferences stay on the Mac. ChineseEcho has no account system, advertising,
cross-app tracking, or developer-operated analytics.

The optional Local AI model is downloaded from Hugging Face. After download,
generation runs locally on Apple silicon. See the full
[Privacy Policy](https://avarzhou-ctrl.github.io/ChineseEcho/privacy/).

## Development

ChineseEcho uses Swift 6, SwiftUI, SwiftData, AVFoundation, and Swift Package
Manager. Open `ChineseEcho.xcodeproj` in Xcode, select the `ChineseEcho` scheme
and **My Mac**, then build or run the app.

From Terminal, an unsigned local Release build can be created with:

```sh
xcodebuild \
  -project ChineseEcho.xcodeproj \
  -scheme ChineseEcho \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Tests

Run the focused regression scripts from the repository root:

```sh
bash tests/continuous_dictation.sh
bash tests/practice_session_completion.sh
bash tests/speech_recovery.sh
```

## Project structure

```text
ChineseEcho/
├── ChineseEcho.xcodeproj/       # Xcode project, target, and shared scheme
├── ChineseEcho/
│   ├── ChineseEchoApp.swift     # Application entry point
│   ├── ContentView.swift        # Root navigation and workspace composition
│   ├── Models/                  # SwiftData models and shared data types
│   ├── Services/                # Storage, speech, review, backup, and Local AI
│   ├── Views/                   # SwiftUI screens and reusable components
│   ├── Resources/               # Dictionary data and third-party notices
│   └── Assets.xcassets/         # App icon, colors, and image assets
├── docs/                        # Public website and release documentation
├── tests/                       # Focused regression scripts
├── README.md                    # Project overview and setup
├── DESIGN.md                    # Product design reference
├── TODO.md                      # Release and QA checklist
└── CHANGELOG.md                 # Dated project history
```

- `ChineseEcho/Models` — SwiftData models and shared data types
- `ChineseEcho/Services` — persistence, speech, review, backup, and Local AI services
- `ChineseEcho/Views` — SwiftUI workspaces and reusable interface components
- `ChineseEcho/Resources` — bundled dictionary and third-party notices
- `docs` — public website, support, privacy, acknowledgements, and release notes
- `tests` — focused regression scripts

## Documentation

- [Release notes](https://avarzhou-ctrl.github.io/ChineseEcho/release-notes-1.0/)
- [Support and troubleshooting](https://avarzhou-ctrl.github.io/ChineseEcho/support/)
- [Privacy policy](https://avarzhou-ctrl.github.io/ChineseEcho/privacy/)
- [Acknowledgements and licenses](https://avarzhou-ctrl.github.io/ChineseEcho/acknowledgements/)
- [Release checklist](TODO.md)

For help, bug reports, or privacy questions, email
[avarzhou@gmail.com](mailto:avarzhou@gmail.com).
