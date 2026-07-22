import AVFoundation
import SwiftData
import SwiftUI

struct SmartDictationView: View {
    let sets: [DictationSet]
    let activeSet: DictationSet?
    let onCreateSet: () -> Void
    let onOpenVocabulary: () -> Void
    let onOpenSet: (DictationSet) -> Void
    let onCloseSet: () -> Void

    @State private var searchText = ""

    private var filteredSets: [DictationSet] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sets }
        return sets.filter { set in
            set.title.localizedCaseInsensitiveContains(query)
                || set.vocabularyWords.contains { word in
                    word.chinese.localizedCaseInsensitiveContains(query)
                        || word.pinyin.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var body: some View {
        Group {
            if let activeSet {
                PracticeSessionView(set: activeSet, onFinish: onCloseSet)
            } else {
                VStack(spacing: 0) {
                    WorkspaceHeader(
                        title: "Smart Dictation",
                        searchText: $searchText,
                        searchPrompt: "Search dictation sets…",
                        showsAddButton: true,
                        addAction: onCreateSet
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            DictationHero(
                                onCreateSet: onCreateSet,
                                onOpenVocabulary: onOpenVocabulary
                            )

                            DictationSetCollection(
                                sets: filteredSets,
                                isSearching: !searchText.isEmpty,
                                onCreateSet: onCreateSet,
                                onOpenSet: onOpenSet
                            )
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
    }
}

private struct DictationHero: View {
    let onCreateSet: () -> Void
    let onOpenVocabulary: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Master your listening with focused audio drills.")
                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(maxWidth: 480, alignment: .leading)

                Text("Build a custom set from the Chinese you are learning, then listen, reveal, and review at your own pace.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .lineSpacing(3)
                    .frame(maxWidth: 510, alignment: .leading)
                    .padding(.top, 12)

                HStack(spacing: 12) {
                    Button(action: onCreateSet) {
                        Label("Create New Set", systemImage: "plus")
                    }
                    .buttonStyle(GreenCapsuleButtonStyle())

                    Button(action: onOpenVocabulary) {
                        Label("View Vocabulary", systemImage: "character.book.closed")
                    }
                    .buttonStyle(OutlineCapsuleButtonStyle())
                }
                .padding(.top, 22)
            }

            Spacer(minLength: 10)

            ZStack {
                Image(systemName: "waveform")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(TingXiePalette.secondary.opacity(0.45))
            }
            .padding(.trailing, 22)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
        .background(
            LinearGradient(
                colors: [TingXiePalette.surface.opacity(0.88), TingXiePalette.surfaceContainer.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
    }
}

private struct DictationSetCollection: View {
    let sets: [DictationSet]
    let isSearching: Bool
    let onCreateSet: () -> Void
    let onOpenSet: (DictationSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Dictation Practice")
                .font(.system(size: 20, weight: .medium, design: .rounded))

            if sets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: isSearching ? "magnifyingglass" : "waveform.badge.plus")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(TingXiePalette.secondary.opacity(0.7))
                    Text(isSearching ? "No matching sets" : "No Sessions Yet")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(isSearching ? "Try a different set name or vocabulary word." : "Create your first custom practice round to start testing your vocabulary.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                    if !isSearching {
                        Button("Create New Set", systemImage: "plus", action: onCreateSet)
                            .buttonStyle(GreenCapsuleButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .tonalCard()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sets) { set in
                        DictationSetRow(set: set) { onOpenSet(set) }
                    }
                }
            }
        }
    }
}

private struct DictationSetRow: View {
    let set: DictationSet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 52, height: 52)
                    .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 5) {
                    Text(set.title)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    HStack(spacing: 12) {
                        Label(set.dateCreated.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        Label("\(set.vocabularyWords.count) words", systemImage: "list.bullet")
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.72))
                }

                Spacer()

                Text("CUSTOM")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(TingXiePalette.surfaceContainerHighest, in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tonalCard()
    }
}

private enum PracticeFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }
}

private struct PracticeSessionView: View {
    @Environment(\.modelContext) private var modelContext

    let set: DictationSet
    let onFinish: () -> Void

    @State private var filter: PracticeFilter = .all
    @State private var currentIndex = 0
    @State private var revealsCharacters = false
    @State private var pendingMissedWordIDs: Set<PersistentIdentifier> = []
    @State private var isContinuousPlaybackActive = false
    @State private var audioEngine = SpeechAudioEngine()

    private var words: [VocabularyWord] {
        switch filter {
        case .all: set.vocabularyWords
        case .missed: set.vocabularyWords.filter(isMissed)
        case .idioms: set.vocabularyWords.filter(\.isIdiom)
        }
    }

    private var currentWord: VocabularyWord? {
        guard words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: "Practice Session")

            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT SET")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(TingXiePalette.secondary)
                    Text(set.title)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                }
                Spacer()
                PracticeFilterBar(selection: $filter)
                    .frame(maxWidth: 430)
            }
            .padding(.horizontal, 40)

            Group {
                if words.isEmpty {
                    ContentUnavailableView(
                        "No Words in This Filter",
                        systemImage: "text.magnifyingglass",
                        description: Text("Choose a different category to continue practicing.")
                    )
                } else {
                    practiceContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onAppear {
            audioEngine.selectedVoice = audioEngine.defaultFemaleVoice
            audioEngine.onUtteranceFinished = {
                Task { @MainActor in advanceContinuousPlayback() }
            }
        }
        .onDisappear {
            stopContinuousPlayback()
            audioEngine.onUtteranceFinished = nil
        }
        .onChange(of: filter) { _, _ in
            currentIndex = 0
            restartContinuousPlaybackIfNeeded()
        }
    }

    private var practiceContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            if let currentWord {
                PracticeWordCard(word: currentWord, revealsCharacters: revealsCharacters)
                    .frame(maxWidth: 650, minHeight: 300, maxHeight: 360)

                HStack(spacing: 30) {
                    PracticeRoundButton(
                        title: isContinuousPlaybackActive ? "STOP AUDIO" : "PLAY AUDIO",
                        symbol: isContinuousPlaybackActive ? "stop.fill" : "play.fill",
                        color: TingXiePalette.accent,
                        action: toggleContinuousPlayback
                    )

                    Button {
                        revealsCharacters = true
                    } label: {
                        Label(revealsCharacters ? "Characters Revealed" : "Reveal Characters", systemImage: "eye")
                            .frame(minWidth: 245)
                    }
                    .buttonStyle(GreenCapsuleButtonStyle())
                    .disabled(revealsCharacters)
                    .keyboardShortcut(.return, modifiers: [])

                    PracticeRoundButton(
                        title: "MARK MISSED",
                        symbol: "flag",
                        color: TingXiePalette.missed,
                        isDisabled: !revealsCharacters,
                        action: markCurrentWordMissed
                    )
                }
                .padding(.top, 28)
            }

            Spacer(minLength: 22)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Card \(min(currentIndex + 1, words.count)) of \(words.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    ProgressView(value: Double(currentIndex + 1), total: Double(max(words.count, 1)))
                        .tint(TingXiePalette.accent)
                        .frame(maxWidth: 460)
                }

                Spacer()

                Button("Finish Set", systemImage: "rectangle.portrait.and.arrow.right", action: onFinish)
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .padding(.top, 8)
    }

    private func speakCurrentWord() {
        guard let currentWord else { return }
        audioEngine.speak(currentWord.chinese)
    }

    private func toggleContinuousPlayback() {
        if isContinuousPlaybackActive {
            stopContinuousPlayback()
        } else {
            isContinuousPlaybackActive = true
            audioEngine.stop()
            speakCurrentWord()
        }
    }

    private func stopContinuousPlayback() {
        isContinuousPlaybackActive = false
        audioEngine.stop()
    }

    private func restartContinuousPlaybackIfNeeded() {
        guard isContinuousPlaybackActive else { return }
        audioEngine.stop()
        speakCurrentWord()
    }

    private func advanceContinuousPlayback() {
        guard isContinuousPlaybackActive else { return }
        if currentIndex < words.count - 1 {
            currentIndex += 1
            audioEngine.speak(words[currentIndex].chinese)
        } else {
            isContinuousPlaybackActive = false
        }
    }

    private func markCurrentWordMissed() {
        guard let currentWord else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        let wordID = currentWord.persistentModelID
        let markedIndex = currentIndex
        pendingMissedWordIDs.insert(wordID)
        Task {
            do {
                try await store.setMissed(true, wordID: wordID)
                let isStillOnMarkedWord = currentIndex == markedIndex
                    && words.indices.contains(markedIndex)
                    && words[markedIndex].persistentModelID == wordID
                if isStillOnMarkedWord, currentIndex < words.count - 1 {
                    currentIndex += 1
                    restartContinuousPlaybackIfNeeded()
                }
            } catch {
                pendingMissedWordIDs.remove(wordID)
            }
        }
    }

    private func isMissed(_ word: VocabularyWord) -> Bool {
        word.isMissedWord || pendingMissedWordIDs.contains(word.persistentModelID)
    }
}

private struct PracticeFilterBar: View {
    @Binding var selection: PracticeFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PracticeFilter.allCases) { item in
                Button(item.rawValue) { selection = item }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(selection == item ? TingXiePalette.accent : TingXiePalette.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selection == item ? Color.white : .clear, in: Capsule())
            }
        }
        .padding(4)
        .background(TingXiePalette.surfaceContainerHigh, in: Capsule())
    }
}

private struct PracticeWordCard: View {
    let word: VocabularyWord
    let revealsCharacters: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(TingXiePalette.secondary.opacity(0.5))

            Text(word.pinyin.isEmpty ? "Listen carefully" : word.pinyin)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(TingXiePalette.accent)

            HStack(spacing: 12) {
                ForEach(Array(word.chinese.enumerated()), id: \.offset) { _, character in
                    Text(revealsCharacters ? String(character) : "?")
                        .font(.system(size: revealsCharacters ? 40 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(revealsCharacters ? TingXiePalette.accent : TingXiePalette.secondary.opacity(0.18))
                        .frame(width: 64, height: 72)
                        .background(TingXiePalette.surfaceContainerHigh.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TingXiePalette.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: revealsCharacters ? [] : [5]))
                        }
                }
            }

            if !word.englishTranslation.isEmpty {
                Text("Definition: \(word.englishTranslation)")
                    .font(.system(size: 14, design: .rounded).italic())
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.7))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .background(TingXiePalette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.8), lineWidth: 1) }
        .shadow(color: TingXiePalette.accent.opacity(0.11), radius: 28, y: 16)
    }
}

private struct PracticeRoundButton: View {
    let title: String
    let symbol: String
    let color: Color
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.04), in: Circle())
                    .overlay { Circle().stroke(color.opacity(0.25), lineWidth: 1.5) }
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color.opacity(isDisabled ? 0.35 : 1))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct NewDictationSetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String, [NewVocabularyWord]) async throws -> Void

    @State private var title = "HSK 5 full set"
    @State private var sourceText = "把握 | bǎ wò | grasp\n比例 | bǐ lì | proportion\n核心 | hé xīn | core\n必然 | bì rán | inevitable\n反复 | fǎn fù | repeatedly\n集中 | jí zhōng | concentrate\n深刻 | shēn kè | profound\n莫名其妙 | mò míng qí miào | baffling"
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "character.book.closed")
                    .foregroundStyle(TingXiePalette.accent)
                Text("Create New Set")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 28)
            .frame(height: 70)

            Divider().overlay(TingXiePalette.outlineVariant.opacity(0.5))

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Set Name")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    TextField("e.g., HSK 5 full set", text: $title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 9))
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Words")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("CHINESE | PINYIN | TRANSLATION")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(TingXiePalette.secondary)
                    }
                    TextEditor(text: $sourceText)
                        .font(.system(size: 14, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 190)
                        .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 9))
                }

                Label("Type one entry per line. Four-character entries are saved as idioms.", systemImage: "lightbulb")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TingXiePalette.surfaceContainerHighest.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(TingXiePalette.missed)
                }
            }
            .padding(28)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(TingXiePalette.accent)
                Button(action: save) {
                    Label(isSaving ? "Creating…" : "Create", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(GreenCapsuleButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedWords.isEmpty || isSaving)
            }
            .padding(.horizontal, 28)
            .frame(height: 76)
            .background(TingXiePalette.surfaceContainer.opacity(0.65))
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(.ultraThinMaterial)
        .background(TingXiePalette.surface.opacity(0.84))
        .frame(width: 560, height: 570)
    }

    private var parsedWords: [NewVocabularyWord] {
        sourceText.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let chinese = fields.first, !chinese.isEmpty else { return nil }
            return NewVocabularyWord(
                chinese: chinese,
                pinyin: fields.count > 1 ? fields[1] : "",
                translation: fields.count > 2 ? fields[2] : "",
                isIdiom: chinese.count == 4
            )
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = parsedWords
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await onSave(cleanTitle, words)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview("Smart Dictation — Empty") {
    SmartDictationView(
        sets: [], activeSet: nil, onCreateSet: {}, onOpenVocabulary: {},
        onOpenSet: { _ in }, onCloseSet: {}
    )
    .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Smart Dictation — Sets") {
    let hskSet = DictationSet(title: "HSK 5 full set", dateCreated: Date.now.addingTimeInterval(-86_400))
    let idiomSet = DictationSet(title: "Everyday idioms", dateCreated: Date.now.addingTimeInterval(-172_800))
    SmartDictationView(
        sets: [hskSet, idiomSet], activeSet: nil, onCreateSet: {}, onOpenVocabulary: {},
        onOpenSet: { _ in }, onCloseSet: {}
    )
    .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

@MainActor
private func smartDictationPracticePreview() -> some View {
    let set = DictationSet(title: "HSK 5 full set")
    let words = [
        VocabularyWord(chinese: "把握", englishTranslation: "to grasp", pinyin: "bǎ wò", tags: [set.title]),
        VocabularyWord(chinese: "集中", englishTranslation: "to concentrate", pinyin: "jí zhōng", isMissedWord: true, tags: [set.title]),
        VocabularyWord(chinese: "莫名其妙", englishTranslation: "baffling", pinyin: "mò míng qí miào", isIdiom: true, tags: [set.title]),
        VocabularyWord(chinese: "核心", englishTranslation: "core", pinyin: "hé xīn", tags: [set.title])
    ]
    words.forEach { word in word.session = set; set.vocabularyWords.append(word) }
    return SmartDictationView(
        sets: [set], activeSet: set, onCreateSet: {}, onOpenVocabulary: {},
        onOpenSet: { _ in }, onCloseSet: {}
    )
    .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Smart Dictation — Practice") {
    smartDictationPracticePreview()
}
