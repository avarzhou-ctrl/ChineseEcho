import AVFoundation
import SwiftUI

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
    @AppStorage(AppPreferenceKey.automaticProgression)
    private var automaticProgression = AppPreferenceDefault.automaticProgression
    @AppStorage(AppPreferenceKey.keepCardsRevealed)
    private var keepCardsRevealed = AppPreferenceDefault.keepCardsRevealed
    @AppStorage(AppPreferenceKey.generatedWordCount)
    private var generatedWordCount = AppPreferenceDefault.generatedWordCount

    @State private var audioEngine = SpeechAudioEngine()

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
                        "Practice choices control repeats, automatic movement, and whether new cards begin revealed.",
                        "The Practice card also shows your library totals and controls the size of AI-generated sets."
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
            summary: "Control listening sessions, review your library, and choose the size of new AI-generated sets.",
            minimumHeight: primaryCardMinimumHeight
        ) {
            Stepper("Repeat each word \(repeatCount) time\(repeatCount == 1 ? "" : "s")", value: $repeatCount, in: 1...5)
            Toggle("Automatically advance after playback", isOn: $automaticProgression)
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

            Divider()

            SettingsGroupHeading(title: "New Sets", symbol: "sparkles")
            Stepper(
                "Suggest \(generatedWordCount) words for a new set",
                value: $generatedWordCount,
                in: 3...20
            )
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
                Text("MLX Swift")
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

    private func synchronizeAudioEngine() {
        audioEngine.configureFromPreferences()
    }
}

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

private struct SettingsGroupHeading: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(TingXiePalette.accent)
    }
}

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
