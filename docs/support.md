---
layout: default
title: ChineseEcho Support
permalink: /support/
description: Installation help, troubleshooting, backups, speech, and Local AI support for ChineseEcho.
wide: true
---

<header class="page-hero">
  <h1>How can we help?</h1>
  <p>Find installation guidance, troubleshooting steps, and answers for ChineseEcho’s core features.</p>
  <a class="button button-primary" href="mailto:avarzhou@gmail.com">Email support</a>
</header>

<section class="document-section">
  <h2>Installation and updates</h2>
  <div class="faq-list">
    <details open><summary>Why does macOS say ChineseEcho cannot be opened?</summary><div><p>ChineseEcho 1.0 isn’t signed or notarized by Apple, so macOS blocks it the first time you open it. Download it only from the <a href="https://github.com/avarzhou-ctrl/ChineseEcho/releases/tag/v1.0">official GitHub release</a>, move it to Applications, and try opening it once. Then open <strong>System Settings → Privacy &amp; Security</strong>, select <strong>Open Anyway</strong>, authenticate if requested, and open ChineseEcho again.</p><p>If Open Anyway is missing, try opening ChineseEcho once more and return to Privacy &amp; Security. Don’t turn off Gatekeeper, the macOS check that blocks unknown apps, for your whole Mac. If it still won’t open, use the <a href="{{ '/#terminal-fallback' | relative_url }}">one-line Terminal command on the homepage</a>, which affects only ChineseEcho.</p></div></details>
    <details id="verify-download"><summary>How do I verify the download?</summary><div><p>Keep the ZIP and <code>ChineseEcho-1.0-macOS.zip.sha256</code> in the same folder, open Terminal there, and run:</p><pre><code>shasum -a 256 -c ChineseEcho-1.0-macOS.zip.sha256</code></pre><p>The result should say <code>ChineseEcho-1.0-macOS.zip: OK</code>. The expected version 1.0 SHA-256 value is <code>c396dcfdc0e5812c28120a053706eb1be6fc06747c67b05f8dca5fefdc2353b1</code>.</p></div></details>
    <details><summary>How do I update ChineseEcho?</summary><div><p>Quit ChineseEcho, download the newer ZIP, and replace the app in Applications. Do not remove the app’s data container. Your library and preferences stay in place because the new version replaces only the app. Export a backup first when possible.</p></div></details>
  </div>
</section>

<section class="document-section">
  <h2>Using ChineseEcho</h2>
  <div class="faq-list">
    <details><summary>Does ChineseEcho require an account?</summary><div><p>No. ChineseEcho does not require an account or sign-in.</p></div></details>
    <details><summary>Can I use ChineseEcho offline?</summary><div><p>Dictation, vocabulary, practice, review, and native speech work without a ChineseEcho server. Internet access is needed only to download the optional Local AI model. After download, example generation runs locally.</p></div></details>
    <details><summary>Why is Local AI not ready?</summary><div><p>Open <strong>Settings → Local AI</strong> to check its status. The approximately 2.5 GB download requires Apple silicon, available storage, and an internet connection. A paused or interrupted download keeps completed files. Use Retry to continue or Remove Model to clear a damaged download.</p></div></details>
    <details><summary>How do I back up learning data?</summary><div><p>Open <strong>Settings → Practice &amp; Backup</strong> and select <strong>Export Backup</strong>. Choose a destination for the JSON file. Use Import Backup to preview and restore a compatible backup.</p></div></details>
    <details><summary>How do I control review notifications?</summary><div><p>Use <strong>System Settings → Notifications → ChineseEcho</strong>. If reminders do not appear, confirm notifications are allowed, Focus is not suppressing them, and at least one word is due.</p></div></details>
    <details><summary>Why is speech silent or using the wrong pronunciation?</summary><div><p>Open <strong>Settings → Speech</strong>, choose Mainland or Taiwanese Mandarin, and use the preview control. Confirm the Mac is not muted and its output device is correct, then restart ChineseEcho if speech remains unavailable.</p></div></details>
    <details><summary>Why can’t I export or restore a backup?</summary><div><p>ChineseEcho can access only locations selected through the macOS save or open panel. Choose the location again, confirm the drive is available, and verify that your user can write there.</p></div></details>
    <details><summary>How do I delete learning data?</summary><div><p>Delete vocabulary or dictation sets inside ChineseEcho. Remove downloaded Local AI files from <strong>Settings → Local AI</strong>. Contact support if you need help locating other locally stored data.</p></div></details>
  </div>
</section>

<section class="page-endcap"><h2>Still need help?</h2><p>Email <a href="mailto:avarzhou@gmail.com">avarzhou@gmail.com</a> with your macOS and ChineseEcho versions, what you expected, what happened, and the steps that cause it if you know them.</p><p class="endcap-note">Please don’t attach vocabulary, backups, or other learning data unless it’s needed to investigate. For how data is stored, read the <a href="{{ '/privacy/' | relative_url }}">Privacy Policy</a>.</p></section>
