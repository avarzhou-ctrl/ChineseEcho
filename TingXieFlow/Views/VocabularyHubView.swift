import SwiftData
import SwiftUI

// Defines the catalog subsets available in the vocabulary workspace.
private enum VocabularyFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }
}

// Coordinates vocabulary filtering, search, selection, editing, review state, and deletion.
struct VocabularyHubView: View {
    @Environment(\.modelContext) private var modelContext

    let words: [VocabularyWord]
    @Binding var selectedWordID: PersistentIdentifier?

    @State private var searchText = ""
    @State private var isSearchResultsPresented = false
    @State private var highlightedSearchWordID: PersistentIdentifier?
    @State private var filter: VocabularyFilter = .all
    @State private var pendingLearnedWordIDs: Set<PersistentIdentifier> = []
    @State private var editingWord: VocabularyWord?
    @State private var wordPendingDeletion: VocabularyWord?
    @State private var operationError: String?

    private var categoryWords: [VocabularyWord] {
        words.filter { word in
            switch filter {
            case .all: true
            case .missed: isEffectivelyMissed(word)
            case .idioms: word.isIdiom
            }
        }
    }

    private var filteredWords: [VocabularyWord] {
        let query = searchText.tingXieTrimmed
        guard !query.isEmpty else { return categoryWords }

        return categoryWords.filter { word in
            SearchText.matches(word.chinese, query: query)
                || SearchText.matchesPinyin(word.pinyin, query: query)
                || SearchText.matches(word.englishTranslation, query: query)
                || word.tags.contains { SearchText.matches($0, query: query) }
        }
    }

    private var selectedWord: VocabularyWord? {
        if let selectedWordID,
           let selected = words.first(where: { $0.persistentModelID == selectedWordID }),
           categoryWords.contains(where: { $0.persistentModelID == selectedWordID }) {
            return selected
        }
        return categoryWords.first
    }

    private var searchResultsOverlay: AnyView {
        AnyView(
            SearchResultsPanel(
                resultCount: filteredWords.count,
                emptyMessage: "No matching vocabulary in \(filter.rawValue)",
                onClear: clearSearch
            ) {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredWords) { word in
                            VocabularySearchResultRow(
                                word: word,
                                isMissed: isEffectivelyMissed(word),
                                isHighlighted: highlightedSearchWordID == word.persistentModelID,
                                onHover: { highlightedSearchWordID = word.persistentModelID },
                                onSelect: { openSearchResult(word) }
                            )
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 320)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Your Vocabulary Hub",
                searchText: $searchText,
                searchPrompt: "Search words, meanings, or tags…",
                searchAccessibilityLabel: "Search vocabulary, translations, and tags",
                searchResults: searchResultsOverlay,
                searchResultsPresented: $isSearchResultsPresented,
                onSearchSubmit: openHighlightedSearchResult,
                onMoveSearchSelection: moveSearchSelection,
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
            .onTapGesture { isSearchResultsPresented = false }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onChange(of: selectedWordID) { _, newSelection in
            guard newSelection != nil else { return }
            filter = .all
            searchText = ""
        }
        .onChange(of: searchText) { _, _ in
            highlightedSearchWordID = filteredWords.first?.persistentModelID
            isSearchResultsPresented = !searchText.tingXieTrimmed.isEmpty
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

            if categoryWords.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: emptyStateSymbol,
                    description: Text(emptyStateDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(categoryWords) { word in
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
        .onChange(of: filter) { _, _ in
            selectedWordID = nil
            highlightedSearchWordID = filteredWords.first?.persistentModelID
        }
    }

    private var emptyStateTitle: String {
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

    private func clearSearch() {
        searchText = ""
        isSearchResultsPresented = false
        highlightedSearchWordID = nil
    }

    private func openSearchResult(_ word: VocabularyWord) {
        clearSearch()
        selectedWordID = word.persistentModelID
    }

    private func openHighlightedSearchResult() {
        guard !filteredWords.isEmpty else { return }
        let word = filteredWords.first {
            $0.persistentModelID == highlightedSearchWordID
        } ?? filteredWords[0]
        openSearchResult(word)
    }

    private func moveSearchSelection(_ direction: Int) {
        guard !filteredWords.isEmpty else {
            highlightedSearchWordID = nil
            return
        }
        let currentIndex = filteredWords.firstIndex {
            $0.persistentModelID == highlightedSearchWordID
        } ?? (direction > 0 ? -1 : 0)
        let nextIndex = min(max(currentIndex + direction, 0), filteredWords.count - 1)
        highlightedSearchWordID = filteredWords[nextIndex].persistentModelID
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

// Presents vocabulary categories as a full-width segmented control.
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
                .background(
                    selection == item ? Color.white : .clear,
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Displays one vocabulary record and its contextual row actions.
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

// Highlights the fields that matched a vocabulary search query.
private struct VocabularySearchResultRow: View {
    let word: VocabularyWord
    let isMissed: Bool
    let isHighlighted: Bool
    let onHover: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(word.chinese)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(isMissed ? TingXiePalette.missed : TingXiePalette.accent)
                    .frame(minWidth: 52, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(TingXiePalette.onBackground)
                        .lineLimit(1)
                    Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 5) {
                    if isMissed {
                        SearchResultBadge(title: "Missed", color: TingXiePalette.missed)
                    }
                    if word.isIdiom {
                        SearchResultBadge(title: "Idiom", color: TingXiePalette.secondary)
                    }
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .background(.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(TingXiePalette.accent.opacity(0.55), lineWidth: 1)
            }
        }
        .onHover { hovering in
            if hovering { onHover() }
        }
        .accessibilityLabel("Open \(word.chinese), \(word.pinyin), \(word.englishTranslation)")
    }
}

// Labels why a search result matched without changing the underlying record.
private struct SearchResultBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// Shows pronunciation, meaning, tags, Local AI enrichment, and word-level actions.
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
                            Text(word.chinese)
                                .font(.system(size: word.chinese.count > 3 ? 62 : 88, weight: .bold, design: .rounded))
                                .foregroundStyle(TingXiePalette.accent)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)

                            Spacer()

                            WordTags(word: word, compact: false, showsMissed: isMissed)
                                .padding(.top, 10)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(TingXiePalette.secondary.opacity(0.72))

                            Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(TingXiePalette.onBackground)

                            Spacer(minLength: 12)

                            Button {
                                audioEngine.stop()
                                audioEngine.speak(word.chinese)
                            } label: {
                                Label("Play Audio", systemImage: "speaker.wave.2.fill")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(TingXiePalette.accent)
                            .background(TingXiePalette.surfaceContainerHighest, in: Capsule())
                            .accessibilityLabel("Play \(word.chinese)")
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(TingXiePalette.surfaceContainerHigh.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TingXiePalette.outlineVariant.opacity(0.55), lineWidth: 1)
                        }
                        .padding(.top, 14)

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

// Standardizes headings within the vocabulary inspector.
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

// Lays out every stored tag for the selected vocabulary word.
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

// Renders a single vocabulary tag as a compact capsule.
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

// Validates and saves editable fields for an existing vocabulary record.
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
// Seeds the populated preview with representative regular, missed, and idiom records.
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
