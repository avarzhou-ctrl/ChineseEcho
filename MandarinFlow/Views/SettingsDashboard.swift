import AVFoundation
import SwiftData
import SwiftUI

// Presents persisted speech, practice, local-data, and app-information settings.
struct SettingsDashboard: View {
    @Environment(\.modelContext) private var modelContext

    let setCount: Int
    let wordCount: Int
    var onShowTutorial: () -> Void = {}

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
    @State private var isModelStorageLoading = true
    @State private var isConfirmingModelRemoval = false
    @State private var modelRemovalError: String?
    @State private var backupDocument: MandarinFlowBackupDocument?
    @State private var importedBackup: MandarinFlowBackup?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var isRestoringBackup = false
    @State private var backupMessage: String?
    @State private var backupError: String?

    private let sampleText = "今天我们练习听写。"

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Settings",
                info: WorkspaceInfo(
                    title: "About Settings",
                    symbol: "gearshape",
                    summary: "These preferences are stored locally on this Mac and apply to future MandarinFlow practice sessions.",
                    tips: [
                        "Speech choices change the voice, pace, pitch, and pause used during dictation.",
                        "Local AI manages the private on-device model used for enrichment and contextual sentences.",
                        "Practice & Backup controls card playback and moves your local learning library between Macs."
                    ]
                )
            )

            ScrollView {
                VStack(spacing: 18) {
                    speechSection
                    localAISection
                    practiceAndBackupSection
                }
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
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
        .task {
            await modelDownloadCoordinator.refreshCachedByteCount()
            isModelStorageLoading = false
        }
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
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "MandarinFlow Backup"
        ) { result in
            if case .failure(let error) = result {
                backupError = error.localizedDescription
            } else {
                backupMessage = "Backup exported successfully."
            }
        }
        .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) {
            importBackup(from: $0)
        }
        .sheet(
            isPresented: Binding(
                get: { importedBackup != nil },
                set: { if !$0 { importedBackup = nil } }
            )
        ) {
            if let importedBackup {
                BackupRestorePreview(
                    backup: importedBackup,
                    currentSetCount: setCount,
                    currentWordCount: wordCount,
                    isRestoring: isRestoringBackup,
                    errorMessage: backupError,
                    onCancel: { self.importedBackup = nil },
                    onRestore: { restore(importedBackup) }
                )
            }
        }
    }

    private var speechSection: some View {
        SettingsSectionCard(
            title: "Speech & Pronunciation",
            symbol: "speaker.wave.2.fill",
            summary: "Choose how native Apple speech reads every dictation word."
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
                .buttonStyle(TingXieButtonStyle(size: .compact))
                .tutorialTarget(.voicePreviewButton)

                Button("Stop", systemImage: "stop.fill") {
                    audioEngine.stop()
                }
                .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))
            }
        }
    }

    private var practiceAndBackupSection: some View {
        SettingsSectionCard(
            title: "Practice & Backup",
            symbol: "externaldrive.fill",
            summary: "Control card playback and import or export your local learning library."
        ) {
            Stepper(value: $repeatCount, in: 1...5) {
                Text("Repeat each word \(repeatCount) time\(repeatCount == 1 ? "" : "s")")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $keepCardsRevealed) {
                Text("Begin each new card with the answer shown")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            SettingsGroupHeading(title: "Local Backup", symbol: "externaldrive.fill")
            HStack(spacing: 10) {
                Button("Export Backup", systemImage: "square.and.arrow.up", action: exportBackup)
                    .buttonStyle(TingXieButtonStyle(size: .compact))
                    .disabled(isRestoringBackup)

                Button("Import Backup", systemImage: "square.and.arrow.down") {
                    backupError = nil
                    backupMessage = nil
                    isImportingBackup = true
                }
                .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))
                .disabled(isRestoringBackup)
            }

            if let backupMessage {
                Label(backupMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TingXiePalette.accent)
            }
            if let backupError, importedBackup == nil {
                Label(backupError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(TingXiePalette.missed)
                    .fixedSize(horizontal: false, vertical: true)
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
                        .font(.system(size: 15, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(modelDownloadCoordinator.statusTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Label(localAIStateLabel, systemImage: localAIStateSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(localAIStateColor)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(localAIStateColor.opacity(0.1), in: Capsule())
            }

            if modelDownloadCoordinator.phase == .downloading {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(modelDownloadCoordinator.statusDetail)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                        Spacer()
                        Text(modelDownloadCoordinator.percentageText)
                            .fontWeight(.bold)
                            .foregroundStyle(TingXiePalette.accent)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)

                    ProgressView(value: modelDownloadCoordinator.fractionCompleted)
                        .progressViewStyle(.linear)
                        .tint(TingXiePalette.accent)
                        .accessibilityLabel("Local AI download progress")
                        .accessibilityValue(modelDownloadCoordinator.percentageText)

                    Label(modelDownloadCoordinator.predictedTimeText, systemImage: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Predicted Local AI download time")
                }
            } else if modelDownloadCoordinator.phase == .checking
                        || modelDownloadCoordinator.phase == .loading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(modelDownloadCoordinator.statusDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(modelDownloadCoordinator.statusDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            LabeledContent("Stored model data") {
                HStack(spacing: 10) {
                    if isModelStorageLoading {
                        SkeletonBlock(width: 72, height: 14, cornerRadius: 4)
                            .accessibilityLabel("Checking stored model data")
                    } else {
                        Text(modelDownloadCoordinator.cachedSizeText)
                            .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    }

                    Button("Remove Model", systemImage: "trash", role: .destructive) {
                        isConfirmingModelRemoval = true
                    }
                    .buttonStyle(TingXieButtonStyle(variant: .destructive, size: .compact))
                    .disabled(isModelStorageLoading || modelDownloadCoordinator.cachedByteCount == 0)
                }
            }

            if modelDownloadCoordinator.isPreparing {
                HStack {
                    Button("Pause Download", systemImage: "pause.fill") {
                        Task { await modelDownloadCoordinator.cancelPreparation() }
                    }
                    .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))

                    Spacer()
                }
            } else if modelDownloadCoordinator.canRetry {
                HStack {
                    Button("Download Model", systemImage: "arrow.down.circle.fill") {
                        modelRemovalError = nil
                        modelDownloadCoordinator.startPreparing()
                    }
                    .buttonStyle(TingXieButtonStyle(size: .compact))

                    Spacer()
                }
            }

            if let modelRemovalError {
                Label(modelRemovalError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(TingXiePalette.missed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func exportBackup() {
        backupError = nil
        backupMessage = nil
        let store = LocalBackupStore(modelContainer: modelContext.container)
        let analytics = PracticeAnalyticsStore.backup()
        let activeSession = PracticeSessionStore.load()
        let reviewSchedulePreferences = ReviewSchedulePreferences.snapshot()
        Task {
            do {
                let backup = try await store.makeBackup(
                    analytics: analytics,
                    activeSession: activeSession,
                    reviewSchedulePreferences: reviewSchedulePreferences
                )
                backupDocument = MandarinFlowBackupDocument(backup: backup)
                isExportingBackup = true
            } catch {
                backupError = error.localizedDescription
            }
        }
    }

    private func importBackup(from result: Result<URL, Error>) {
        backupError = nil
        backupMessage = nil
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            importedBackup = try MandarinFlowBackup.decode(Data(contentsOf: url))
        } catch {
            backupError = error.localizedDescription
        }
    }

    private func restore(_ backup: MandarinFlowBackup) {
        guard !isRestoringBackup else { return }
        isRestoringBackup = true
        backupError = nil
        let store = LocalBackupStore(modelContainer: modelContext.container)
        Task {
            do {
                try await store.replaceLibrary(with: backup)
                PracticeAnalyticsStore.restore(backup.analytics)
                PracticeSessionStore.clear()
                if let activeSession = backup.activeSession {
                    PracticeSessionStore.save(activeSession)
                }
                ReviewSchedulePreferences.restore(
                    backup.reviewSchedulePreferences ?? .defaultValue
                )
                importedBackup = nil
                backupMessage = "Restored \(backup.sets.count) sets and \(backup.wordCount) words."
            } catch {
                backupError = error.localizedDescription
            }
            isRestoringBackup = false
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

// Shows validated restore contents before any existing local data is replaced.
private struct BackupRestorePreview: View {
    let backup: MandarinFlowBackup
    let currentSetCount: Int
    let currentWordCount: Int
    let isRestoring: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 48, height: 48)
                    .background(
                        TingXiePalette.surfaceContainerHighest,
                        in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview Local Restore")
                        .font(TingXieTypography.sectionTitle)
                    Text("Backup created \(backup.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(TingXieTypography.metadata)
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }
            }

            HStack(spacing: 12) {
                RestoreCountComparison(
                    label: "Sets",
                    currentValue: currentSetCount,
                    restoredValue: backup.sets.count
                )
                RestoreCountComparison(
                    label: "Words",
                    currentValue: currentWordCount,
                    restoredValue: backup.wordCount
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Included in this restore", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                Text("Set names and dates, vocabulary, contextual sentences, breakdowns, tags, learner hints, missed-word status, and learning progress.")
                    .font(.system(size: 12))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(
                "Restoring replaces the current learning library and progress on this Mac. Export a backup first if you may need the current data later.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TingXiePalette.missed)
            .padding(12)
            .background(
                TingXiePalette.missed.opacity(0.08),
                in: RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(TingXiePalette.missed)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(TingXieButtonStyle(variant: .quiet))
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRestoring)
                Spacer()
                Button("Replace and Restore", systemImage: "arrow.clockwise", action: onRestore)
                    .buttonStyle(TingXieButtonStyle())
                    .disabled(isRestoring)
            }
        }
        .padding(26)
        .frame(width: 530)
        .background(TingXiePalette.background)
    }
}

// Compares the current library size with the validated incoming backup.
private struct RestoreCountComparison: View {
    let label: String
    let currentValue: Int
    let restoredValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
            HStack(spacing: 8) {
                Text("\(currentValue)")
                Image(systemName: "arrow.right")
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                Text("\(restoredValue)")
                    .fontWeight(.bold)
                    .foregroundStyle(TingXiePalette.accent)
            }
            .font(.system(size: 18))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TingXiePalette.lightGreenSurface,
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
        )
    }
}

// Presents each settings category as a compact macOS-style grouped list.
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TingXiePalette.onBackground)

                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .help(summary)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .tonalCard(
            cornerRadius: TingXieControlMetrics.controlCornerRadius,
            fill: TingXiePalette.lightGreenSurface
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint(summary)
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TingXiePalette.accent)
    }
}

#Preview {
    SettingsDashboard(setCount: 3, wordCount: 24)
}
