# TODO List

## Before 1.0

- [ ] **Finish the MandarinFlow app icon**
  - Prepare the existing logo for every required macOS icon size.
  - Check that the mark remains clear at the smallest Finder and Dock sizes.

- [ ] **Add a first-run tutorial and Local AI download choice**
  - Introduce Smart Dictation, the Vocabulary Hub, and Settings.
  - Explain that Local AI requires a separate on-device model download before it begins.
  - Show the expected download and storage size, with **Download** and **Not Now** actions.
  - Keep the core dictation workflow usable when Local AI is not installed.
  - Let users replay the tutorial from Settings.

## Learning improvements

- [ ] **Add optional learner hints**
  - Allow a short hint to be saved per vocabulary word.
  - Keep hints hidden during listening until the learner requests one.

- [ ] **Add an end-of-session summary**
  - Show accuracy, learned words, and missed words after finishing a set.
  - Offer a one-click **Practice Missed Words** follow-up.

- [ ] **Resume interrupted practice**
  - Restore the active set, current card, queue order, and completed grading after relaunching.
  - Provide a clear action to discard the saved session and start over.

- [ ] **Add local backup and restore**
  - Export sets, vocabulary, contextual sentences, hints, and learning progress to a portable file.
  - Validate imported data and preview what will be restored before changing the library.

- [ ] **Add customizable icons for sets**
  - Emoji, icons, colors, etc.

## Later considerations

- [ ] **Evaluate a due-review queue**
  - Use practice history to surface vocabulary that needs review without replacing normal set practice.
  - Define a simple scheduling model before adding more progress metrics.

## Completed

- [x] **Correct Local AI model naming**
  - Replaced literal `(modelName)` placeholders with the displayed model name in every download status.

- [x] **More intuitive vocabulary page**
  - Reduced text and simplified individual vocabulary navigation.
