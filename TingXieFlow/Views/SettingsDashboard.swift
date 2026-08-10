import AVFoundation
import SwiftUI

// Presents persisted speech, practice, local-data, and app-information settings.
struct SettingsDashboard: View {
    let setCount: Int
    let wordCount: Int

    @AppStorage(AppPreferenceKey.voiceIdentifier) private var voiceIdentifier = ""
    @AppStorage(AppPreferenceKey.pronunciationProfile)
    private var pronunciationProfile = AppPreferenceDefault.pronunciationProfile
    @AppStorage(AppPreferenceKey.speechRate)
    private var speechRate = AppPreferenceDefault.speechRate
    @AppStorage(AppPreferenceKey.speechPitch)
    private var speechPitch = AppPreferenceDefault.speechPitch
    @AppStorage(AppPreferenceKey.interWordPause)
    private var interWordPause = AppPreferenceDefault.interWordPause
    @AppStorage(AppPreferenceKey.repeatCount)
    private var repeatCount = AppPreferenceDefault.repeatCount
    @AppStorage(AppPreferenceKey.keepCardsRevealed)
    private var keepCardsRevealed = AppPreferenceDefault.keepCardsRevealed
    @State private var audioEngine = SpeechAudioEngine()
    @State private var modelDownloadCoordinator = ModelDownloadCoordinator.shared
    @State private var isConfirmingModelRemoval = false
    @State private var modelRemovalError: String?

    private let sampleText = "今天我们练习听写。"
    private let primaryCardMinimumHeight: CGFloat = 470

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Settings",
                info: WorkspaceInfo(
                    title: "About Settings",
                    symbol: "gearshape",
                    summary: "These preferences are stored locally on this Mac and apply to future TingXieFlow practice sessions.",
                    tips: [
                        "Speech choices change the voice, pace, pitch, and pause used during dictation.",
                        "Practice choices control audio repeats and whether new cards begin revealed.",
                        "The Practice card also shows the number of sets and vocabulary words stored on this Mac."
                    ]
                )
            )

            ScrollView {
                VStack(spacing: 18) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 390), spacing: 18)],
                        alignment: .leading,
                        spacing: 18
                    ) {
                        speechSection
                        practiceSection
                    }

                    localAISection
                    aboutSection
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onAppear(perform: synchronizeAudioEngine)
        .onChange(of: voiceIdentifier) { _, _ in synchronizeAudioEngine() }
        .onChange(of: pronunciationProfile) { _, _ in synchronizeAudioEngine() }
        .onChange(of: speechRate) { _, _ in synchronizeAudioEngine() }
        .onChange(of: speechPitch) { _, _ in synchronizeAudioEngine() }
        .onChange(of: interWordPause) { _, _ in synchronizeAudioEngine() }
        .onDisappear { audioEngine.stop() }
        .task { await modelDownloadCoordinator.refreshCachedByteCount() }
        .alert("Remove Local AI Model?", isPresented: $isConfirmingModelRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove Model", role: .destructive) {
                Task {
                    do {
                        try await modelDownloadCoordinator.removeDownloadedModel()
                    } catch {
                        modelRemovalError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("This removes the downloaded \(modelDownloadCoordinator.modelName) files from this Mac. Local AI will be unavailable until the model is downloaded again.")
        }
    }

    private var speechSection: some View {
        SettingsSectionCard(
            title: "Speech & Pronunciation",
            symbol: "speaker.wave.2.fill",
            summary: "Choose how native Apple speech reads every dictation word.",
            minimumHeight: primaryCardMinimumHeight
        ) {
            Picker("Pronunciation", selection: $pronunciationProfile) {
                Text("Mainland Mandarin").tag("Mainland Mandarin")
                Text("Taiwanese Mandarin").tag("Taiwanese Mandarin")
            }
            .pickerStyle(.segmented)

            Picker("Voice", selection: $voiceIdentifier) {
                Text("Automatic").tag("")
                ForEach(audioEngine.voices, id: \.identifier) { voice in
                    Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                }
            }
            .pickerStyle(.menu)

            SettingsSlider(
                title: "Speed",
                value: $speechRate,
                range: 0.35...0.65,
                valueText: String(format: "%.2f", speechRate)
            )
            SettingsSlider(
                title: "Pitch",
                value: $speechPitch,
                range: 0.7...1.4,
                valueText: String(format: "%.1fx", speechPitch)
            )
            SettingsSlider(
                title: "Pause",
                value: $interWordPause,
                range: 0.25...3,
                valueText: String(format: "%.2fs", interWordPause)
            )

            HStack {
                Button {
                    audioEngine.stop()
                    audioEngine.speak(sampleText)
                } label: {
                    Label("Preview Voice", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(TingXiePalette.accent)

                Button("Stop", systemImage: "stop.fill") {
                    audioEngine.stop()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var practiceSection: some View {
        SettingsSectionCard(
            title: "Practice",
            symbol: "rectangle.on.rectangle.angled",
            summary: "Control listening sessions and review your local learning library.",
            minimumHeight: primaryCardMinimumHeight
        ) {
            Stepper("Repeat each word \(repeatCount) time\(repeatCount == 1 ? "" : "s")", value: $repeatCount, in: 1...5)
            Toggle("Begin each new card with the answer shown", isOn: $keepCardsRevealed)

            Label(
                keepCardsRevealed
                    ? "New cards open on the answer side."
                    : "New cards open on the listening side and can be flipped with Return or Space.",
                systemImage: "keyboard"
            )
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(TingXiePalette.onSurfaceVariant)

            Divider()

            SettingsGroupHeading(title: "Learning Library", symbol: "books.vertical.fill")
            HStack(spacing: 12) {
                DataCountBadge(value: setCount, label: "Sets", symbol: "square.stack.3d.up")
                DataCountBadge(value: wordCount, label: "Words", symbol: "character.book.closed")
            }
        }
    }

    private var localAISection: some View {
        SettingsSectionCard(
            title: "Local AI",
            symbol: "cpu.fill",
            summary: "Manage the private on-device model used for vocabulary enrichment and contextual sentences."
        ) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelDownloadCoordinator.modelName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(modelDownloadCoordinator.statusTitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }

                Spacer()

                Label(localAIStateLabel, systemImage: localAIStateSymbol)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(localAIStateColor)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(localAIStateColor.opacity(0.1), in: Capsule())
            }

            if modelDownloadCoordinator.phase == .downloading {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(modelDownloadCoordinator.statusDetail)
                        Spacer()
                        Text(modelDownloadCoordinator.percentageText)
                            .fontWeight(.bold)
                            .foregroundStyle(TingXiePalette.accent)
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)

                    ProgressView(value: modelDownloadCoordinator.fractionCompleted)
                        .progressViewStyle(.linear)
                        .tint(TingXiePalette.accent)
                        .accessibilityLabel("Local AI download progress")
                        .accessibilityValue(modelDownloadCoordinator.percentageText)

                    Label(modelDownloadCoordinator.predictedTimeText, systemImage: "clock")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .accessibilityLabel("Predicted Local AI download time")
                }
            } else if modelDownloadCoordinator.phase == .checking
                        || modelDownloadCoordinator.phase == .loading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(modelDownloadCoordinator.statusDetail)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }
            } else {
                Text(modelDownloadCoordinator.statusDetail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }

            Divider()

            LabeledContent("Stored model data") {
                Text(modelDownloadCoordinator.cachedSizeText)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }

            HStack(spacing: 10) {
                if modelDownloadCoordinator.isPreparing {
                    Button("Pause Download", systemImage: "pause.fill") {
                        Task { await modelDownloadCoordinator.cancelPreparation() }
                    }
                    .buttonStyle(.bordered)
                } else if modelDownloadCoordinator.canRetry {
                    Button("Download Model", systemImage: "arrow.down.circle.fill") {
                        modelRemovalError = nil
                        modelDownloadCoordinator.startPreparing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TingXiePalette.accent)
                }

                Spacer()

                Button("Remove Model", systemImage: "trash", role: .destructive) {
                    isConfirmingModelRemoval = true
                }
                .buttonStyle(.bordered)
                .disabled(modelDownloadCoordinator.cachedByteCount == 0)
            }

            if let modelRemovalError {
                Label(modelRemovalError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(TingXiePalette.missed)
            }

            Label(
                "Preparation starts in the background at app launch. Pausing keeps downloaded files so the next attempt can resume.",
                systemImage: "info.circle"
            )
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(TingXiePalette.onSurfaceVariant)
        }
    }

    private var aboutSection: some View {
        SettingsSectionCard(
            title: "About",
            symbol: "info.circle.fill",
            summary: "An audio-first Chinese learning workspace built for private, focused practice."
        ) {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            LabeledContent("Storage") {
                Text("Local on this Mac")
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            LabeledContent("Speech") {
                Text("Apple AVSpeechSynthesizer")
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            LabeledContent("Language Model") {
                Text("\(LocalModelSpec.displayName) · MLX Swift")
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            LabeledContent("Dictionary") {
                Text("CC-CEDICT · CC BY-SA 4.0")
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return switch (version, build) {
        case let (version?, build?): "\(version) (\(build))"
        case let (version?, nil): version
        default: "Development"
        }
    }

    private var localAIStateLabel: String {
        switch modelDownloadCoordinator.phase {
        case .idle: "Not Downloaded"
        case .checking: "Checking"
        case .downloading: "Downloading"
        case .loading: "Loading"
        case .ready: "Ready"
        case .cancelled: "Paused"
        case .failed: "Needs Attention"
        }
    }

    private var localAIStateSymbol: String {
        switch modelDownloadCoordinator.phase {
        case .ready: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "pause.circle.fill"
        case .downloading: "arrow.down.circle.fill"
        case .loading: "cpu"
        default: "circle.dashed"
        }
    }

    private var localAIStateColor: Color {
        switch modelDownloadCoordinator.phase {
        case .ready: TingXiePalette.accent
        case .failed: TingXiePalette.missed
        default: TingXiePalette.secondary
        }
    }

    private func synchronizeAudioEngine() {
        audioEngine.configureFromPreferences()
    }
}

// Gives each settings category a consistent titled card container.
private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let symbol: String
    let summary: String
    let minimumHeight: CGFloat?
    let content: Content

    init(
        title: String,
        symbol: String,
        summary: String,
        minimumHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.minimumHeight = minimumHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 42, height: 42)
                    .background(TingXiePalette.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(TingXiePalette.accent)
                    Text(summary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .lineSpacing(2)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                content
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .tonalCard(cornerRadius: 18)
    }
}

// Standardizes labeled sliders with a trailing formatted value.
private struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 44, alignment: .leading)
            Slider(value: $value, in: range)
            Text(valueText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// Renders a compact heading for a related group of settings controls.
private struct SettingsGroupHeading: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(TingXiePalette.accent)
    }
}

// Displays one local-data count as a reusable labeled badge.
private struct DataCountBadge: View {
    let value: Int
    let label: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(TingXiePalette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(TingXiePalette.surfaceContainer.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SettingsDashboard(setCount: 3, wordCount: 24)
}
