# App Store Release Checklist

## Verified Baseline

- [x] Build the unsigned Release configuration for both `arm64` and `x86_64`.
- [x] Pass the release QA, browser smoke, and browser branch regression scripts.
- [x] Provide a complete macOS app icon set.
- [x] Enable App Sandbox, outbound network access, and user-selected file read/write access.

## Submission Blockers

- [x] Add an in-app Privacy section and publish a public privacy-policy URL.
  - Explain that vocabulary, practice history, generated content, and preferences stay on the device.
  - Disclose that the optional Local AI model is downloaded from Hugging Face unless its delivery method changes.
  - Explain where local data and downloaded models are stored and how users can delete them.
  - Link the public privacy policy from Settings.
- [ ] Set the macOS application category to Education (`public.app-category.education`) and use the same category in App Store Connect.
- [ ] Configure App Store distribution signing.
  - Select the paid Apple Developer team.
  - Register or confirm the App ID.
  - Create a signed Release archive with automatic signing.
  - Run Xcode's Validate App workflow and resolve every error or warning.
- [ ] Decide and document the supported Mac architectures.
  - If Local AI requires Apple silicon, ship `arm64` only or clearly disable Local AI on Intel.
  - If `x86_64` remains supported, test the complete app on a real Intel Mac before submission.
- [ ] Finalize the Local AI model-delivery plan.
  - Confirm whether the approximately 2.5 GB Qwen model will remain a Hugging Face download or move to Apple-hosted Background Assets.
  - Verify download, pause, resume, failure, removal, and low-disk-space behavior in the sandboxed signed app.
  - Give App Review exact instructions for testing both the app without the model and the optional Local AI flow.
- [ ] Add a Legal/Acknowledgements screen or bundled notices covering CC-CEDICT, Qwen, MLX, Hugging Face tooling, and all other redistributed dependencies or data licenses.

## App Store Connect Setup

- [ ] Confirm the permanent bundle identifier before the first upload.
  - Current identifier: `com.avarzhou.TingXieFlow`.
  - Keep it for continuity or change it to ChineseEcho before release; ensure the App Store Connect record matches exactly.
- [ ] Create the macOS app record for ChineseEcho with a unique SKU, version `1.0`, and the correct primary language.
- [ ] Complete the age-rating questionnaire; do not select the Kids category unless the product and policies are intentionally designed for it.
- [ ] Complete the content-rights declaration for the dictionary data, model, and other included or downloaded content.
- [ ] Complete App Privacy accurately after a final telemetry and networking audit. If nothing is transmitted for tracking or developer collection, declare “Data Not Collected.”
- [ ] Complete export-compliance questions. Add `ITSAppUsesNonExemptEncryption = NO` only if the final app and Apple's questionnaire support that answer.
- [ ] Provide a working privacy-policy URL and support URL with a way to contact the developer.
- [ ] Write the app name, subtitle, description, keywords, promotional text, copyright, and release notes.
- [ ] Choose pricing, territories, availability, and manual or automatic release.
- [ ] Complete Digital Services Act trader-status requirements for distribution in the EU.
- [ ] Complete the Paid Applications agreement, tax forms, and banking details if the app or any future in-app purchase is paid.
- [ ] Add App Review contact details and review notes.
  - State that no account or login is required.
  - Explain that Local AI is optional and the core learning experience works without downloading it.
  - Disclose the model's approximate download size and provide exact test steps.

## Product Page Assets

- [ ] Capture 1–10 clean macOS screenshots at an accepted 16:10 resolution, such as 1440×900, without transparency.
- [ ] Include representative screenshots for Smart Dictation, immersive practice, Vocabulary, Settings, and the optional Local AI experience.
- [ ] Check every screenshot for personal data, debug content, clipped UI, inconsistent branding, and outdated features.
- [ ] Add localized metadata and screenshots for every language that will be supported at launch.
- [ ] Create an optional app preview only if it materially improves the product page.

## Final Release QA

- [ ] Test the signed archived build or TestFlight build rather than relying only on Debug builds.
- [ ] Test first launch on a clean macOS user account with no existing app data, model cache, or permissions.
- [ ] Test onboarding with Local AI accepted, declined, interrupted, and retried.
- [ ] Test notification authorization, denial, disabled system notifications, and due-review delivery.
- [ ] Test backup export and restore using files selected through the sandboxed save/open panels.
- [ ] Test offline use before and after the optional model has been downloaded.
- [ ] Test model download, pause, resume, cancellation, network failure, app relaunch, removal, and insufficient storage.
- [ ] Test Light Mode, Dark Mode, Reduce Motion, VoiceOver, keyboard navigation, focus order, and minimum window size.
- [ ] Test SwiftData persistence, interrupted-session restoration, backup compatibility, and upgrading from the previous public build.
- [ ] Test every supported architecture on real hardware: Apple silicon, plus Intel only if `x86_64` remains supported.
- [ ] Confirm all user-visible names, icons, versions, links, copyright text, and privacy statements agree across the app, archive, and App Store Connect.
- [ ] Increment the build number for every uploaded archive.

## Submit for Review

- [ ] Archive and upload the signed Release build from Xcode.
- [ ] Wait for App Store Connect processing and resolve all processing warnings.
- [ ] Select the processed build and complete any build-specific compliance questions.
- [ ] Add the version for review, complete the final checklist, and submit it.
- [ ] Monitor review messages and respond with reproducible steps or a corrected build when requested.
- [ ] Release manually or automatically according to the selected rollout plan.
