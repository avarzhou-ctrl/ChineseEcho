---
layout: default
title: ChineseEcho Support
permalink: /support/
---

# ChineseEcho Support

ChineseEcho is a native macOS app for Chinese dictation, vocabulary practice,
scheduled review, and optional on-device example generation.

## Contact

For help, bug reports, or privacy questions, email
[avarzhou@gmail.com](mailto:avarzhou@gmail.com).

When reporting a problem, please include:

- Your macOS version
- Your ChineseEcho version
- What you expected to happen
- What happened instead
- Steps that reproduce the problem, if known

Please do not attach vocabulary, backup files, or other personal learning data
unless it is necessary to investigate the issue.

## Frequently asked questions

### Why does macOS say ChineseEcho cannot be opened?

ChineseEcho 1.0 is distributed without an Apple Developer Program membership,
so it is not signed or notarized by Apple. After downloading from the official
[GitHub release](https://github.com/avarzhou-ctrl/ChineseEcho/releases/tag/v1.0):

1. Move `ChineseEcho.app` to **Applications**.
2. Try to open it once.
3. Open **System Settings → Privacy & Security**.
4. Select **Open Anyway** beside the ChineseEcho message.
5. Enter your Mac login password if requested and open ChineseEcho again.

If **Open Anyway** is missing, try opening ChineseEcho once more and return to
Privacy & Security. Do not disable Gatekeeper globally.

### How do I verify the download?

The GitHub release includes `ChineseEcho-1.0-macOS.zip.sha256`. In Terminal,
change to the folder containing both downloaded files and run:

```sh
shasum -a 256 -c ChineseEcho-1.0-macOS.zip.sha256
```

The result should say `ChineseEcho-1.0-macOS.zip: OK`. Delete the files and
download them again from the official release if the check fails.

For version 1.0, the expected SHA-256 value is
`6925693cc9ae9aa20fd4a86aab175480736450287227cf7df4cf14bd55e9a429`.

### How do I update ChineseEcho manually?

Quit ChineseEcho, download the newer ZIP from the official release page, and
replace the existing app in **Applications**. Do not delete ChineseEcho's data
container or choose a cleanup option that removes app data. Your SwiftData
library and preferences use the stable bundle identifier
`com.avarzhou.TingXieFlow` and remain in place when the app bundle is replaced.
Export a backup from **Settings → Practice & Backup** before updating when
possible.

### Does ChineseEcho require an account?

No. ChineseEcho does not require an account or sign-in.

### Can I use ChineseEcho offline?

Dictation, vocabulary management, practice, review, and native speech work
without a ChineseEcho server. An internet connection is required to download
the optional Local AI model. After a successful download, example generation
runs locally on your Mac.

### Why is Local AI not ready?

Open **Settings → Local AI** to view its status. The model download is
approximately 2.5 GB and can be paused or retried. Confirm that your Mac has
enough free storage and a working internet connection.

Local AI requires an Apple-silicon Mac. If a download fails, select Retry. A
paused or interrupted download keeps completed files and continues later. Use
**Remove Model** to clear a damaged or unwanted download before trying again.

### How do I remove the Local AI model?

Open **Settings → Local AI**, select **Remove Model**, and confirm. You can
download the model again later.

### How do I back up my learning data?

Open **Settings → Practice & Backup** and select **Export Backup**. Choose a
location for the JSON backup file. Use **Import Backup** to preview and restore
a compatible ChineseEcho backup.

### How do I control review notifications?

Use **System Settings → Notifications → ChineseEcho** to change notification
permissions, sounds, and presentation options.

If reminders do not appear, confirm that notifications are allowed, Focus is
not suppressing them, and at least one word is due for review.

### Speech is silent or uses the wrong pronunciation

Open **Settings → Speech**, choose Mainland or Taiwanese Mandarin, and use the
preview control. Confirm the Mac is not muted and its output device is correct.
Restart ChineseEcho if macOS speech remains unavailable.

### Backup export or restore is blocked

ChineseEcho can access only locations selected in the macOS save or open
panel. Choose the destination again, confirm the drive is available, and make
sure the current user can write there. Restore accepts compatible ChineseEcho
JSON backups and shows a preview before replacing the library.

### How do I delete learning data?

Delete vocabulary or dictation sets from within ChineseEcho. Downloaded Local
AI files can be removed separately from **Settings → Local AI**. Contact support
if you need help locating or removing other locally stored ChineseEcho data.

## Privacy

See the [ChineseEcho Privacy Policy](../privacy/) for information about local
storage, the optional model download, retention, and deletion.

[Return to the ChineseEcho homepage](../)
