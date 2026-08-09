# TODO List

- [x] **Restrict “Mark as Learned” to missed words**
  - Show or enable the action only when the selected word has the **Missed** status or flag icon.
  - Activating it should remove the missed status immediately, update the icon and styling, and remove the word from the **Missed Words** filter without deleting it from the vocabulary library.

- [x] **Add contextual information modals**
  - Add info buttons to major sections such as Smart Dictation, Vocabulary Hub, practice sessions, and Settings.
  - Each modal should briefly explain the section’s purpose, core controls, and important behaviors.
  - Use a reusable native SwiftUI modal component with a clear title, SF Symbol, concise guidance, and close action.

- [x] **Fix “Word of the Day”**
  - Replace the permanently hardcoded word with a dynamically selected saved vocabulary word.
  - Keep the selected word stable for the entire calendar day and choose a new one the next day.
  - Display characters, pinyin, and translation, with sensible fallback content when the vocabulary library is empty.
  - Consider making the card clickable so it opens that word in Vocabulary Hub.

- [x] **Define the Settings section**
  - Turn Settings from a diagnostics landing page into a clearly structured preferences area.
  - Add a **Speech & Pronunciation** group for voice, Mainland/Taiwanese pronunciation profile, speed, pitch, and audio preview.
  - Add a **Practice** group for repeat count, delay between words, automatic progression, and reveal behavior.
  - Add a **Local AI** group for model status, download and storage information, generation preferences, and a test prompt.
  - Add a **Data & Export** group for Anki export, local-data management, and reset options.
  - Add an **About** group for app version, privacy information, acknowledgements, and help.
  - Persist user-facing preferences between launches.

- [x] **Use AI to enrich new-set vocabulary**
  - Accept Chinese words separated by commas, spaces, or new lines.
  - Preserve the supplied words and order while filling in pinyin and English translations automatically.
  - Present the generated entries for review before saving.
  - Let users add, edit, reorder, or remove words and manually correct AI output.
  - Preserve a manual-entry fallback when generation fails or the model is unavailable.

- [x] **Add ellipsis editing menus**
  - Add a trailing `ellipsis` menu to dictation-set rows and other editable items.
  - Set actions should include **Rename**, **Edit Words**, **Duplicate**, and **Delete**.
  - Word actions should include **Edit**, **Mark Missed/Mark Learned**, and **Remove from Set** where appropriate.
  - Require confirmation for destructive actions and preserve the currently selected item after non-destructive edits.

- [x] **Replace “Reveal Characters” with flip cards**
  - Make the practice card itself flippable instead of using a separate reveal button.
  - The front should prioritize listening and show pinyin or a listening prompt; the back should show Chinese characters, pinyin, translation, and status.
  - Support clicking the card and pressing Return or Space to flip it.
  - Use a subtle 3D rotation with reduced-motion support.
  - Reset each new word to the front unless the learner explicitly enables persistent reveal behavior.

- [x] **Build a dedicated Missed Words experience in Vocabulary Hub**
  - Ensure the **Missed Words** tab contains only flagged vocabulary and displays a clear Missed tag alongside the existing red treatment.
  - Provide the same search, selection, playback, sentence generation, and inspection features available under **All Words**.
  - Add a tailored empty state explaining that missed words appear after being flagged during practice.
  - Removing a word’s missed status should update the list immediately.

- [x] **Make the entire tab shape clickable**
  - Expand each tab’s hit target to cover its complete rounded segment, including its padding and background.
  - Apply this consistently to the Smart Dictation practice filters and Vocabulary Hub filters.
  - Preserve keyboard navigation, focus indicators, hover feedback, and accessibility labels.

- [x] **Move the Smart Dictation add button to a floating position**
  - Remove the add button from the Smart Dictation header.
  - Add a floating circular `plus` button in the bottom-right corner of the page.
  - Keep it visible above scrolling content with safe margins and a sufficiently large hit target.
  - Give it a tooltip and accessibility label such as **Create New Set**.
  - Avoid duplicating the primary creation action unnecessarily in populated states; retain an obvious creation action in the empty state.
