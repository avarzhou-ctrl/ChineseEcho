---
layout: default
title: ChineseEcho
description: Practice Chinese listening, vocabulary, and review in a private native macOS workspace.
---

<section class="hero">
  <div class="hero-copy">
    <h1>Listen. Learn. <span>Remember.</span></h1>
    <p class="hero-lede">Build stronger Chinese listening and recall with focused dictation, thoughtful review, and optional on-device AI—all in one calm workspace.</p>
    <div class="hero-actions">
      <a class="button button-primary" href="https://github.com/avarzhou-ctrl/ChineseEcho/releases/download/v1.0/ChineseEcho-1.0-macOS.zip">Download for Apple silicon <span aria-hidden="true">↓</span></a>
      <a class="button button-secondary" href="#features">Explore features</a>
    </div>
    <div class="terminal-command" id="terminal-fallback">
      <div class="command-row">
        <code data-copy-source>xattr -cr /Applications/ChineseEcho.app</code>
        <button class="copy-command" type="button" data-copy-button aria-label="Copy Terminal command"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 8h10v12H9zM5 16H4V4h10v1"/></svg><span>Copy</span></button>
      </div>
      <p class="command-note">If Open Anyway doesn’t work, run this after moving ChineseEcho to Applications; it only removes the downloaded-from-the-internet mark from this app, and macOS security stays on.</p>
      <p class="copy-status" role="status" aria-live="polite"></p>
    </div>
    <ul class="hero-meta" aria-label="Release details">
      <li>Version 1.0</li><li>macOS 15.6+</li><li>Free and local-first</li>
    </ul>
  </div>
  <div class="hero-art">
    <div class="hero-icon-halo" aria-hidden="true"></div>
    <img class="hero-screenshot" src="{{ '/assets/images/smart-dictation-dashboard.png' | relative_url }}" alt="ChineseEcho Smart Dictation dashboard showing due review and recent practice sets" width="2480" height="1474" decoding="async" fetchpriority="high">
  </div>
</section>

<section class="home-section" id="features">
  <div class="section-heading" data-reveal>
    <h2>From first listen to lasting recall.</h2>
    <p>ChineseEcho keeps practice, vocabulary, and review connected without turning learning into a dashboard of distractions.</p>
  </div>
  <figure class="section-screenshot" data-reveal data-reveal-delay="1">
    <img src="{{ '/assets/images/practice-session.png' | relative_url }}" alt="ChineseEcho practice session showing a Chinese flashcard with pronunciation and grading controls" width="2480" height="1474" loading="lazy" decoding="async">
  </figure>
  <div class="learning-loop" data-reveal data-reveal-delay="2">
    <article class="loop-step">
      <h3>Listen <span lang="zh-Hans">听</span></h3>
      <ul>
        <li><strong>Smart Dictation</strong>Practice custom vocabulary with native Mandarin speech, flexible speed, and Mainland or Taiwanese pronunciation.</li>
        <li><strong>Paper-friendly sessions</strong>Run continuous dictation with repetition, writing time, pause, replay, and navigation controls.</li>
      </ul>
    </article>
    <article class="loop-step">
      <h3>Review <span lang="zh-Hans">复习</span></h3>
      <ul>
        <li><strong>Scheduled review</strong>Return to missed and due words through a local five-box review system shaped by your results.</li>
        <li><strong>Vocabulary library</strong>Keep words, meanings, pinyin, tags, idioms, and optional learner hints organized in one place.</li>
      </ul>
    </article>
    <article class="loop-step">
      <h3>Remember <span lang="zh-Hans">记住</span></h3>
      <ul>
        <li><strong>Context that sticks</strong>Use optional Local AI to create modern bilingual examples privately on your Apple-silicon Mac.</li>
        <li><strong>Portable backups</strong>Export and restore a versioned JSON backup of your library, learning history, and preferences.</li>
      </ul>
    </article>
  </div>
</section>

<section class="home-section">
  <div class="privacy-panel" data-reveal>
    <div><h2>Your learning stays yours.</h2></div>
    <div>
      <p>Vocabulary, practice history, generated examples, and preferences remain on your Mac. ChineseEcho has no account system, advertising, cross-app tracking, or developer-operated analytics.</p>
      <a class="button privacy-policy-button" href="{{ '/privacy/' | relative_url }}">Read the privacy policy</a>
      <div class="trust-list">
        <div><strong>Local storage</strong><span>Stored only on your Mac</span></div>
        <div><strong>Native speech</strong><span>Powered by macOS</span></div>
        <div><strong>Optional AI</strong><span>Runs on-device after download</span></div>
      </div>
    </div>
  </div>
  <figure class="section-screenshot privacy-section-screenshot" data-reveal data-reveal-delay="1">
    <img src="{{ '/assets/images/vocabulary-library.png' | relative_url }}" alt="ChineseEcho vocabulary library showing word details and bilingual example sentences" width="2480" height="1474" loading="lazy" decoding="async">
  </figure>
</section>

<section class="home-section" id="install">
  <div class="install-grid" data-reveal>
    <div class="requirement-card">
      <h2>Built for modern Macs.</h2>
      <ul class="requirement-list">
        <li><span><strong>Apple silicon</strong><br>M1 or newer</span></li>
        <li><span><strong>macOS 15.6</strong><br>or a later release</span></li>
        <li><span><strong>Optional Local AI</strong><br>Approximately 2.5 GB and internet for its initial download</span></li>
      </ul>
    </div>
    <div class="install-card">
      <h2>Install ChineseEcho</h2>
      <ol class="install-steps">
        <li>Download and unzip <strong>ChineseEcho-1.0-macOS.zip</strong>.</li>
        <li>Drag <strong>ChineseEcho.app</strong> into Applications.</li>
        <li>Try opening ChineseEcho once, then open <strong>System Settings → Privacy &amp; Security</strong>.</li>
        <li>Select <strong>Open Anyway</strong>, authenticate if asked, and open ChineseEcho again. If that doesn’t work, use the <a href="#terminal-fallback">Terminal command</a> under the first download button.</li>
      </ol>
      <div class="hero-actions">
        <a class="button button-primary" href="https://github.com/avarzhou-ctrl/ChineseEcho/releases/download/v1.0/ChineseEcho-1.0-macOS.zip">Download for Apple silicon</a>
        <a class="button button-secondary" href="{{ '/support/' | relative_url }}">Installation help</a>
      </div>
      <p class="release-line">Version 1.0, released October 3, 2026. <a href="{{ '/release-notes-1.0/' | relative_url }}">Read the release notes</a></p>
    </div>
  </div>
</section>
