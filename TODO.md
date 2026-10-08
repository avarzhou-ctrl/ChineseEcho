# Direct Download Release Checklist

ChineseEcho will initially ship as a free, unsigned macOS download without an Apple Developer Program membership. macOS will require each user to approve the app manually in System Settings before first launch.

## Verified Baseline

- [x] Build the unsigned Release configuration for Apple silicon (`arm64`).
- [x] Pass the continuous-dictation, practice-session-completion, and speech-recovery regression scripts.
- [x] Provide a complete macOS app icon set.
- [x] Enable App Sandbox, outbound network access, and user-selected file read/write access.
- [x] Add an in-app Privacy section and publish public privacy, support, and acknowledgements pages.

## Direct Download Blockers

- [x] Set the macOS application category to Education (`public.app-category.education`).
- [x] Ship the initial release for Apple silicon (`arm64`) and document the M1-or-newer requirement.
- [x] Finalize the Local AI model-delivery plan around the current Hugging Face download.
  - Pin `mlx-community/Qwen3-4B-4bit` to revision `4dcb3d101c2a062e5c1d4bb173588c54ea6c4d25`.
  - Show the approximately 2.5 GB download size and Apple-silicon requirement before download.
  - Check available storage before starting an incomplete download, including a 500 MB safety margin.
  - Keep Local AI optional so dictation, vocabulary, review, speech, backup, and restore work without it.
  - Exercise download interruption and error scenarios during Final Release QA below.
- [x] Add an in-app Acknowledgements & Licenses screen with bundled offline notices covering CC-CEDICT, Qwen, MLX, Hugging Face tooling, and resolved dependencies.
- [x] Retain `com.avarzhou.TingXieFlow` as the permanent bundle identifier to preserve existing local SwiftData and preferences.
- [x] Confirm marketing version `1.0` and initial Release build number `1`; increment the build number for every downloadable update.
- [x] Audit the Release app for hardcoded developer paths, debug menus, test content, secrets, and development-only settings; exclude standalone developer scratchpads from Release compilation.

## Package the App

- [x] In Xcode, select `My Mac`, choose **Product → Archive**, and confirm the Release archive succeeds.
- [x] In Organizer, choose **Distribute App → Copy App** to export the unsigned `ChineseEcho.app`.
- [x] Apply a complete ad-hoc signature to the exported app, preserving its sandbox entitlements, then compress it as `ChineseEcho-1.0-macOS.zip` while preserving the app bundle and executable permissions.
- [x] Calculate a portable SHA-256 checksum file for the final ZIP.
- [x] Confirm the extracted app can be moved to `/Applications` and launched after the required Gatekeeper approval.
- [x] Keep the exact released ZIP so reported issues can be reproduced against the public build.

## Download and Installation Documentation

- [x] Choose the initial download host: a versioned GitHub Release.
- [x] Add a prominent download link and macOS requirements to the public website.
- [x] Publish first-launch instructions:
  1. Download and unzip ChineseEcho.
  2. Drag `ChineseEcho.app` to Applications.
  3. Try to open the app once.
  4. Open **System Settings → Privacy & Security** and choose **Open Anyway**.
  5. Enter the Mac login password if requested, then open ChineseEcho again.
- [x] Explain beside the download button that the warning appears because the app is not signed or notarized by Apple.
- [x] Tell users to download only from the official release page and verify the published checksum when possible.
- [x] Document how to update manually without deleting existing SwiftData learning data.
- [x] Provide a support contact and troubleshooting steps for blocked launch, model download, speech, notifications, backup, and restore.

## Download Page Assets

- [ ] Capture clean screenshots for Smart Dictation, continuous dictation, Vocab Review, Vocabulary, Settings, and optional Local AI.
- [ ] Check every screenshot for personal data, debug content, clipped UI, inconsistent branding, and outdated features.
- [x] Write a concise product description, system requirements, privacy summary, version number, release date, and release notes.
- [x] State that the ZIP is limited to Apple silicon.

## Final Release QA

- [x] Test the exported Release app rather than relying only on Debug builds.
- [ ] Download the final ZIP through the public link and test it on a separate Mac or clean macOS user account so quarantine and Gatekeeper behavior are exercised.
- [x] Verify that the installation instructions match the quarantined unsigned-app warning and approval flow.
- [ ] Test first launch with no existing app data, model cache, or permissions.
- [ ] Test onboarding with Local AI accepted, declined, interrupted, and retried.
- [ ] Test notification authorization, denial, disabled system notifications, and due-review delivery.
- [ ] Test backup export and restore using files selected through the sandboxed save/open panels.
- [ ] Test offline use before and after the optional model has been downloaded.
- [ ] Test model download, pause, resume, cancellation, network failure, app relaunch, removal, and insufficient storage.
- [ ] Test Light Mode, Dark Mode, Reduce Motion, VoiceOver, keyboard navigation, focus order, and minimum window size.
- [ ] Test SwiftData persistence, interrupted-session restoration, backup compatibility, and upgrading from the previous public build.
- [x] Test the Apple-silicon Release app on real Apple-silicon hardware.
- [x] Confirm all user-visible names, icons, versions, links, copyright text, and privacy statements agree across the app, ZIP, website, and release notes.

## Publish the Download

- [x] Create the versioned `v1.0` release and upload the tested ZIP and checksum file.
- [ ] Replace the `v1.0` ZIP and checksum assets with the corrected ad-hoc-signed package that passes strict bundle verification.
- [x] Add release notes, supported macOS versions and architectures, file size, model-download requirements, SHA-256 checksum, and installation instructions.
- [x] Download the public assets once more and verify the checksum, extracted architecture, and app version.
- [ ] Download and verify the corrected public assets after replacing the `v1.0` files.
- [x] Link the release from the live ChineseEcho website and support page.
- [x] Keep older releases available when replacements are published; `v1.0` is the initial release.

## Deferred Until Apple Developer Membership

- [ ] Join the Apple Developer Program when a normal one-click installation experience or App Store distribution is needed.
- [ ] Sign with a Developer ID certificate, enable Hardened Runtime, notarize the direct-download build, and replace the unsigned ZIP.
- [ ] Re-test the notarized download on a clean Mac and remove the Gatekeeper override instructions when they are no longer required.
- [ ] If publishing in the Mac App Store, configure App Store distribution signing and complete the App Store Connect metadata, compliance, screenshots, pricing, availability, review notes, upload, and submission workflow.
