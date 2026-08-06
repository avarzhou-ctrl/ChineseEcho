import SwiftData
import SwiftUI

private enum VocabularyFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }
}

struct VocabularyHubView: View {
    @Environment(\.modelContext) private var modelContext

    let words: [VocabularyWord]
    @Binding var selectedWordID: PersistentIdentifier?

    @State private var searchText = ""
    @State private var filter: VocabularyFilter = .all
    @State private var pendingLearnedWordIDs: Set<PersistentIdentifier> = []
    @State private var editingWord: VocabularyWord?
    @State private var wordPendingDeletion: VocabularyWord?
    @State private var operationError: String?

    private var filteredWords: [VocabularyWord] {
        words.filter { word in
            let matchesFilter = switch filter {
            case .all: true
            case .missed: isEffectivelyMissed(word)
            case .idioms: word.isIdiom
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || word.chinese.localizedCaseInsensitiveContains(query)
                || word.pinyin.localizedCaseInsensitiveContains(query)
                || word.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesFilter && matchesSearch
        }
    }

    private var selectedWord: VocabularyWord? {
        if let selectedWordID,
           let selected = words.first(where: { $0.persistentModelID == selectedWordID }),
           filteredWords.contains(where: { $0.persistentModelID == selectedWordID }) {
            return selected
        }
        return filteredWords.first
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Your Vocabulary Hub",
                searchText: $searchText,
                searchPrompt: "Search characters, pinyin, or tags…",
                info: WorkspaceInfo(
                    title: "About the Vocabulary Hub",
                    symbol: "character.book.closed",
                    summary: "Review every saved word, focus on missed items, listen again, and enrich vocabulary with private on-device sentence generation.",
                    tips: [
                        "Use the full-width tabs to switch between all words, missed words, and idioms.",
                        "Red text and a Missed tag identify words marked during dictation practice.",
                        "Mark As Learned removes only the missed status; the word remains safely in your vocabulary."
                    ]
                )
            )

            HSplitView {
                vocabularyCatalog
                    .frame(minWidth: 390, idealWidth: 440)

                VocabularyInspector(
                    word: selectedWord,
                    isMissed: selectedWord.map(isEffectivelyMissed) ?? false,
                    onMarkAsLearned: markAsLearned
                )
                    .frame(minWidth: 360, idealWidth: 500)
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onChange(of: selectedWordID) { _, newSelection in
            guard newSelection != nil else { return }
            filter = .all
            searchText = ""
        }
        .sheet(item: $editingWord) { word in
            WordEditorSheet(word: word) { chinese, pinyin, translation, isIdiom in
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.updateWord(
                    wordID: word.persistentModelID,
                    chinese: chinese,
                    pinyin: pinyin,
                    translation: translation,
                    isIdiom: isIdiom
                )
            }
        }
        .alert(
            "Remove “\(wordPendingDeletion?.chinese ?? "Word")”?",
            isPresented: Binding(
                get: { wordPendingDeletion != nil },
                set: { if !$0 { wordPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { wordPendingDeletion = nil }
            Button("Remove", role: .destructive) { deletePendingWord() }
        } message: {
            Text("This removes the word from its dictation set and the Vocabulary Hub.")
        }
        .alert(
            "Couldn’t Update Vocabulary",
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button("OK") { operationError = nil }
        } message: {
            Text(operationError ?? "Please try again.")
        }
    }

    private var vocabularyCatalog: some View {
        VStack(spacing: 20) {
            VocabularyFilterBar(selection: $filter)

            if filteredWords.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: emptyStateSymbol,
                    description: Text(emptyStateDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredWords) { word in
                            VocabularyRow(
                                word: word,
                                isSelected: word.persistentModelID == selectedWord?.persistentModelID,
                                isMissed: isEffectivelyMissed(word),
                                onSelect: { selectedWordID = word.persistentModelID },
                                onEdit: { editingWord = word },
                                onToggleMissed: { setMissed(!isEffectivelyMissed(word), for: word) },
                                onDelete: { wordPendingDeletion = word }
                            )
                        }
                    }
                }
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 24)
        .padding(.bottom, 32)
        .background(TingXiePalette.background)
        .onChange(of: filter) { _, _ in selectedWordID = nil }
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty { return "No Matching Vocabulary" }
        return switch filter {
        case .all: "No Vocabulary Yet"
        case .missed: "No Missed Words"
        case .idioms: "No Idioms Yet"
        }
    }

    private var emptyStateSymbol: String {
        return switch filter {
        case .all: "character.book.closed"
        case .missed: "flag.slash"
        case .idioms: "text.book.closed"
        }
    }

    private var emptyStateDescription: String {
        if !searchText.isEmpty {
            return "Try another character, pinyin spelling, or set tag."
        }
        switch filter {
        case .all:
            return "Words from your dictation sets will appear here."
        case .missed:
            return "Words you flag during practice will appear here for focused review."
        case .idioms:
            return "Four-character entries saved as idioms will appear here."
        }
    }

    private func isEffectivelyMissed(_ word: VocabularyWord) -> Bool {
        word.isMissedWord && !pendingLearnedWordIDs.contains(word.persistentModelID)
    }

    private func markAsLearned(_ word: VocabularyWord) {
        setMissed(false, for: word)
    }

    private func setMissed(_ isMissed: Bool, for word: VocabularyWord) {
        let wordID = word.persistentModelID
        if isMissed {
            pendingLearnedWordIDs.remove(wordID)
        } else {
            guard word.isMissedWord else { return }
            pendingLearnedWordIDs.insert(wordID)
        }

        Task {
            do {
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.setMissed(isMissed, wordID: wordID)
            } catch {
                pendingLearnedWordIDs.remove(wordID)
                operationError = error.localizedDescription
            }
        }
    }

    private func deletePendingWord() {
        guard let wordPendingDeletion else { return }
        let wordID = wordPendingDeletion.persistentModelID
        self.wordPendingDeletion = nil
        if selectedWordID == wordID {
            selectedWordID = nil
        }

        Task {
            do {
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.deleteWord(wordID: wordID)
            } catch {
                operationError = error.localizedDescription
            }
        }
    }
}

private struct VocabularyFilterBar: View {
    @Binding var selection: VocabularyFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(VocabularyFilter.allCases) { item in
                Button {
                    selection = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == item ? TingXiePalette.accent : TingXiePalette.onSurfaceVariant)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selection == item ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct VocabularyRow: View {
    let word: VocabularyWord
    let isSelected: Bool
    let isMissed: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleMissed: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    Text(word.chinese)
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundStyle(isMissed ? TingXiePalette.missed : TingXiePalette.onBackground)
                        .frame(minWidth: 78, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        WordTags(word: word, compact: true, showsMissed: isMissed)
                    }

                    Spacer()
                }
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, minHeight: 76)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit Word", systemImage: "pencil", action: onEdit)
                Button(
                    isMissed ? "Mark As Learned" : "Mark Missed",
                    systemImage: isMissed ? "checkmark.circle" : "flag",
                    action: onToggleMissed
                )
                Divider()
                Button("Remove from Set", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.trailing, 20)
            .help("Edit \(word.chinese)")
            .accessibilityLabel("Edit \(word.chinese)")

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.5))
                .padding(.trailing, 16)
        }
        .background(
            isSelected ? TingXiePalette.surface : Color.clear,
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(TingXiePalette.outlineVariant.opacity(0.65), lineWidth: 1)
            }
        }
    }
}

private struct VocabularyInspector: View {
    @Environment(\.modelContext) private var modelContext

    let word: VocabularyWord?
    let isMissed: Bool
    let onMarkAsLearned: (VocabularyWord) -> Void

    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var audioEngine = SpeechAudioEngine()

    var body: some View {
        Group {
            if let word {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(word.chinese)
                                    .font(.system(size: word.chinese.count > 3 ? 62 : 88, weight: .bold, design: .rounded))
                                    .foregroundStyle(TingXiePalette.accent)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)

                                HStack(spacing: 10) {
                                    Text(word.pinyin)
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    Button {
                                        audioEngine.stop()
                                        audioEngine.speak(word.chinese)
                                    } label: {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .frame(width: 38, height: 38)
                                            .background(TingXiePalette.surfaceContainerHighest, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(TingXiePalette.accent)
                                    .accessibilityLabel("Play \(word.chinese)")
                                }
                            }

                            Spacer()

                            WordTags(word: word, compact: false, showsMissed: isMissed)
                                .padding(.top, 10)
                        }

                        Divider()
                            .overlay(TingXiePalette.outlineVariant.opacity(0.5))
                            .padding(.vertical, 22)

                        InspectorSectionTitle("Translation")
                        Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                            .font(.system(size: 22, design: .rounded))
                            .lineSpacing(4)
                            .padding(.top, 10)

                        HStack {
                            InspectorSectionTitle("Contextual Sentences")
                            Spacer()
                            Button(action: regenerateSentence) {
                                if isGenerating {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Regenerate", systemImage: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(TingXiePalette.accent)
                            .disabled(isGenerating)
                        }
                        .padding(.top, 34)

                        Text(word.generatedSentence ?? "Generate one natural, short Chinese example sentence for this word.")
                            .font(.system(size: 17, design: .rounded))
                            .lineSpacing(5)
                            .padding(20)
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                            .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 12)

                        if let generationError {
                            Label(generationError, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(TingXiePalette.missed)
                                .padding(.top, 10)
                        }

                        if isMissed {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(
                                    "This word is in Missed Words.",
                                    systemImage: "flag.fill"
                                )
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(TingXiePalette.missed)

                                Button(
                                    "Mark As Learned",
                                    systemImage: "checkmark.circle"
                                ) {
                                    onMarkAsLearned(word)
                                }
                                .buttonStyle(GreenCapsuleButtonStyle())
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 34)
                        }
                    }
                    .padding(30)
                }
            } else {
                ContentUnavailableView(
                    "No Vocabulary Yet",
                    systemImage: "character.book.closed",
                    description: Text("Words from your dictation sets will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TingXiePalette.surface.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.7), lineWidth: 1) }
        .padding(.trailing, 40)
        .padding(.bottom, 32)
        .onAppear { audioEngine.configureFromPreferences() }
        .onDisappear { audioEngine.stop() }
    }

    private func regenerateSentence() {
        guard let word else { return }
        let wordID = word.persistentModelID
        let prompt = "请用“\(word.chinese)”写一个自然、简短的现代中文句子。只输出句子。"
        isGenerating = true
        generationError = nil

        Task {
            do {
                let sentence = try await generateText(prompt: prompt)
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.setGeneratedSentence(sentence, wordID: wordID)
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
    }

}

private struct InspectorSectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(TingXiePalette.secondary.opacity(0.65))
    }
}

private struct WordTags: View {
    let word: VocabularyWord
    let compact: Bool
    var showsMissed: Bool? = nil

    var body: some View {
        HStack(spacing: 5) {
            if word.isIdiom { TagLabel(text: "Idiom", color: .orange, compact: compact) }
            if showsMissed ?? word.isMissedWord {
                TagLabel(text: "Missed", color: TingXiePalette.missed, compact: compact)
            }
            if let tag = word.tags.first { TagLabel(text: tag, color: TingXiePalette.secondary, compact: compact) }
        }
    }
}

private struct TagLabel: View {
    let text: String
    let color: Color
    let compact: Bool

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 9 : 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 7 : 9)
            .frame(height: compact ? 20 : 24)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .lineLimit(1)
    }
}

private struct WordEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String, String, String, Bool) async throws -> Void

    @State private var chinese: String
    @State private var pinyin: String
    @State private var translation: String
    @State private var isIdiom: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        word: VocabularyWord,
        onSave: @escaping (String, String, String, Bool) async throws -> Void
    ) {
        self.onSave = onSave
        _chinese = State(initialValue: word.chinese)
        _pinyin = State(initialValue: word.pinyin)
        _translation = State(initialValue: word.englishTranslation)
        _isIdiom = State(initialValue: word.isIdiom)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Edit Vocabulary", systemImage: "pencil")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .frame(height: 68)

            Divider()

            Form {
                TextField("Chinese", text: $chinese)
                TextField("Pinyin", text: $pinyin)
                TextField("English Translation", text: $translation)
                Toggle("Treat as an idiom", isOn: $isIdiom)
            }
            .formStyle(.grouped)
            .padding(12)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(TingXiePalette.missed)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(TingXiePalette.accent)
                Button(isSaving ? "Saving…" : "Save", action: save)
                    .buttonStyle(GreenCapsuleButtonStyle())
                    .disabled(cleanChinese.isEmpty || isSaving)
            }
            .padding(.horizontal, 24)
            .frame(height: 70)
            .background(TingXiePalette.surfaceContainer.opacity(0.55))
        }
        .frame(width: 480, height: 400)
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
    }

    private var cleanChinese: String {
        chinese.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onSave(
                    cleanChinese,
                    pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation.trimmingCharacters(in: .whitespacesAndNewlines),
                    isIdiom
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview("Vocabulary Hub — Empty") {
    VocabularyHubView(words: [], selectedWordID: .constant(nil))
        .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

@MainActor
private func populatedVocabularyHubPreview() -> some View {
    let setTitle = "HSK 5 full set"
    let idiom = VocabularyWord(
        chinese: "莫名其妙", englishTranslation: "Baffling; without rhyme or reason",
        pinyin: "mò míng qí miào", isMissedWord: true, isIdiom: true, tags: [setTitle]
    )
    idiom.generatedSentence = "他今天突然朝我发脾气，真是莫名其妙。"
    let words = [
        VocabularyWord(chinese: "把握", englishTranslation: "to grasp", pinyin: "bǎ wò", tags: [setTitle]),
        VocabularyWord(chinese: "集中", englishTranslation: "to concentrate", pinyin: "jí zhōng", isMissedWord: true, tags: [setTitle]),
        VocabularyWord(chinese: "核心", englishTranslation: "core", pinyin: "hé xīn", tags: [setTitle]),
        VocabularyWord(chinese: "反复", englishTranslation: "repeatedly", pinyin: "fǎn fù", tags: [setTitle]),
        idiom
    ]
    return VocabularyHubView(words: words, selectedWordID: .constant(nil))
        .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Vocabulary Hub — Populated") {
    populatedVocabularyHubPreview()
}
