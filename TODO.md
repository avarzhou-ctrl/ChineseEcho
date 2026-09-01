# TODO List

## Before 1.0

- [ ] **Finish the MandarinFlow app icon**
  - Prepare the existing logo for every required macOS icon size.
  - Check that the mark remains clear at the smallest Finder and Dock sizes.

- [x] **Add a first-run tutorial and Local AI download choice**
  - Introduce Smart Dictation, the Vocabulary Hub, and Settings.
  - Explain that Local AI requires a separate on-device model download before it begins.
  - Show the expected download and storage size, with **Download** and **Not Now** actions.
  - Keep the core dictation workflow usable when Local AI is not installed.
  - Let users replay the tutorial from Settings.

## Fixes

- [ ] **Change start page**
  - Should start with previews of the different word cards and choice between all words or idioms review

- [ ] **Card memory**
  - When going to another page and returning, the card should be the same as when the user originally left (i.e. keep an order somehwere).
  - Sets should not start from the beginning.

- [ ] **Adding quotation marks around phrases with puncutation in them""
  - e.g. “新三年，旧三年，缝缝补补又三年”

## Learning improvements

- [x] **Add optional learner hints**
  - Allow a short hint to be saved per vocabulary word.
  - Keep hints hidden during listening until the learner requests one.

- [x] **Add an end-of-session summary**
  - Show accuracy, learned words, and missed words after finishing a set.
  - Offer a one-click **Practice Missed Words** follow-up.

- [x] **Resume interrupted practice**
  - Restore the active set, current card, queue order, and completed grading after relaunching.
  - Provide a clear action to discard the saved session and start over.

- [x] **Add local backup and restore**
  - Export sets, vocabulary, contextual sentences, hints, and learning progress to a portable file.
  - Validate imported data and preview what will be restored before changing the library.

- [x] **Add customizable icons for sets**
  - Choose a curated SF Symbol or emoji and an accent color while creating or editing a set.
  - Preserve the appearance through duplication, local backup, and restore.

- [x] **Add skeleton loaders**
  - All pages

## Later considerations

- [x] **Add a due-review queue**
  - Surface scheduled vocabulary above recent dictation practice without replacing normal set practice or Word of the Day.
  - Use a five-box Known/Missed schedule with cross-set practice, Undo, resume, and backup support.
  - Request macOS notification permission natively and follow the earliest due review.

## Completed

- [x] **Correct Local AI model naming**
  - Replaced literal `(modelName)` placeholders with the displayed model name in every download status.

- [x] **More intuitive vocabulary page**
  - Reduced text and simplified individual vocabulary navigation.
