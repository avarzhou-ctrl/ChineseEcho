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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let words: [VocabularyWord]
    @Binding var selectedWordID: PersistentIdentifier?

    @State private var searchText = ""
    @State private var isSearchResultsPresented = false
    @State private var highlightedSearchWordID: PersistentIdentifier?
    @State private var filter: VocabularyFilter = .all
    @State private var filterTransitionEdge: Edge = .trailing
    @State private var inspectorTransitionEdge: Edge = .trailing
    @State private var selectionOriginatesInCatalog = false
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

    private var animatedFilter: Binding<VocabularyFilter> {
        Binding(
            get: { filter },
            set: updateFilter
        )
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

                ZStack {
                    VocabularyInspector(
                        word: selectedWord,
                        isMissed: selectedWord.map(isEffectivelyMissed) ?? false,
                        onMarkAsLearned: markAsLearned
                    )
                    .id(selectedWord?.persistentModelID)
                    .transition(
                        TingXieMotion.directionalTransition(
                            enteringFrom: inspectorTransitionEdge,
                            reduceMotion: reduceMotion
                        )
                    )
                }
                .animation(
                    TingXieMotion.contentChange(reduceMotion: reduceMotion),
                    value: selectedWord?.persistentModelID
                )
                .frame(minWidth: 420, idealWidth: 560)
                .clipped()
            }
            .onTapGesture { isSearchResultsPresented = false }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onChange(of: selectedWordID) { _, newSelection in
            guard newSelection != nil else { return }
            if selectionOriginatesInCatalog {
                selectionOriginatesInCatalog = false
                return
            }
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
            VocabularyFilterBar(selection: animatedFilter)

            ZStack {
                Group {
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
                                        onSelect: { selectWord(word) },
                                        onEdit: { editingWord = word },
                                        onToggleMissed: { setMissed(!isEffectivelyMissed(word), for: word) },
                                        onDelete: { wordPendingDeletion = word }
                                    )
                                    .transition(TingXieMotion.rowTransition(reduceMotion: reduceMotion))
                                }
                            }
                            .animation(
                                TingXieMotion.contentChange(reduceMotion: reduceMotion),
                                value: categoryWords.map(\.persistentModelID)
                            )
                        }
                    }
                }
                .id(filter)
                .transition(
                    TingXieMotion.directionalTransition(
                        enteringFrom: filterTransitionEdge,
                        reduceMotion: reduceMotion
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(
                TingXieMotion.contentChange(reduceMotion: reduceMotion),
                value: filter
            )
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

    private func updateFilter(_ newFilter: VocabularyFilter) {
        guard newFilter != filter else { return }
        let filters = VocabularyFilter.allCases
        let oldIndex = filters.firstIndex(of: filter) ?? 0
        let newIndex = filters.firstIndex(of: newFilter) ?? 0
        filterTransitionEdge = newIndex > oldIndex ? .trailing : .leading
        filter = newFilter
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
        selectWord(word)
    }

    private func selectWord(_ word: VocabularyWord) {
        let currentID = selectedWord?.persistentModelID
        let newID = word.persistentModelID
        guard currentID != newID else { return }

        let oldIndex = categoryWords.firstIndex {
            $0.persistentModelID == currentID
        } ?? 0
        let newIndex = categoryWords.firstIndex {
            $0.persistentModelID == newID
        } ?? oldIndex
        inspectorTransitionEdge = newIndex >= oldIndex ? .trailing : .leading

        withAnimation(TingXieMotion.contentChange(reduceMotion: reduceMotion)) {
            selectionOriginatesInCatalog = true
            selectedWordID = newID
        }
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
        SlidingFilterBar(
            items: VocabularyFilter.allCases,
            selection: $selection,
            selectionShape: AnyShape(RoundedRectangle(cornerRadius: 9)),
            containerShape: AnyShape(RoundedRectangle(cornerRadius: 12)),
            title: \.rawValue
        )
    }
}

// Displays one vocabulary record and its contextual row actions.
private struct VocabularyRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .font(TingXieTypography.vocabulary(size: 30, weight: .medium))
                        .foregroundStyle(isMissed ? TingXiePalette.missed : TingXiePalette.onBackground)
                        .frame(minWidth: 78, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                            .font(.system(size: 14, weight: .medium))
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
            isSelected ? TingXiePalette.lightGreenSurface : Color.clear,
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(TingXiePalette.outlineVariant.opacity(0.65), lineWidth: 1)
            }
        }
        .animation(
            TingXieMotion.contentChange(reduceMotion: reduceMotion),
            value: isSelected
        )
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
                    .font(TingXieTypography.vocabulary(size: 24))
                    .foregroundStyle(isMissed ? TingXiePalette.missed : TingXiePalette.accent)
                    .frame(minWidth: 52, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TingXiePalette.onBackground)
                        .lineLimit(1)
                    Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                        .font(.system(size: 12))
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
            .font(.system(size: 9, weight: .bold))
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
    @State private var modelDownloadCoordinator = ModelDownloadCoordinator.shared

    var body: some View {
        Group {
            if let word {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 18) {
                            Text(word.chinese)
                                .font(TingXieTypography.vocabulary(size: word.chinese.count > 3 ? 52 : 66, weight: .bold))
                                .foregroundStyle(TingXiePalette.accent)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)

                            Spacer()
                        }

                        HStack(spacing: 12) {
                            Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(TingXiePalette.onBackground)

                            Button {
                                audioEngine.stop()
                                audioEngine.speak(word.chinese)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .background(TingXiePalette.surfaceContainerHigh, in: Circle())
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(TingXiePalette.accent)
                            .help("Play \(word.chinese)")
                            .accessibilityLabel("Play \(word.chinese)")

                            WordTags(word: word, compact: false, showsMissed: isMissed)

                            Spacer(minLength: 8)
                        }
                        .padding(.top, 8)

                        Divider()
                            .overlay(TingXiePalette.outlineVariant.opacity(0.5))
                            .padding(.vertical, 18)

                        InspectorSectionTitle("Meaning")
                        Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                            .font(TingXieTypography.sectionTitle)
                            .lineSpacing(3)
                            .padding(.top, 7)

                        HStack(alignment: .center) {
                            InspectorSectionTitle("Contextual Sentences")
                            Spacer()
                            Button(action: regenerateSentence) {
                                if modelDownloadCoordinator.phase == .downloading {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text(modelDownloadCoordinator.percentageText)
                                    }
                                } else if modelDownloadCoordinator.isPreparing {
                                    Label("Preparing AI", systemImage: "cpu")
                                } else if isGenerating {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label(
                                        contextualSentences.isEmpty ? "Generate" : "Regenerate",
                                        systemImage: contextualSentences.isEmpty ? "sparkles" : "arrow.clockwise"
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TingXiePalette.accent)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                            .disabled(isGenerating || modelDownloadCoordinator.isPreparing)
                            .help(
                                contextualSentences.isEmpty
                                    ? "Generate two contextual sentences"
                                    : "Replace both contextual sentences"
                            )
                        }
                        .padding(.top, 26)

                        if contextualSentences.isEmpty {
                            Text("No sentences generated yet")
                                .font(TingXieTypography.body)
                                .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.7))
                                .padding(.top, 10)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(contextualSentences) { example in
                                    ContextualSentenceCard(
                                        example: example,
                                        chineseVocabulary: word.chinese,
                                        englishMeaning: word.englishTranslation
                                    )
                                }
                            }
                            .padding(.top, 12)
                        }

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
                                .font(.system(size: 12, weight: .semibold))
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
                            .padding(.top, 26)
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .background(TingXiePalette.background)
        .onAppear { audioEngine.configureFromPreferences() }
        .onDisappear { audioEngine.stop() }
    }

    private func regenerateSentence() {
        guard let word else { return }
        let wordID = word.persistentModelID
        isGenerating = true
        generationError = nil

        Task {
            do {
                let sentence = try await ContextualSentenceGenerator.generateStoredSentence(
                    chinese: word.chinese,
                    englishTranslation: word.englishTranslation
                )
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.setGeneratedSentence(sentence, wordID: wordID)
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private var contextualSentences: [ContextualSentence] {
        ContextualSentencePayload.storedExamples(from: word?.generatedSentence)
    }

}

// Presents one example with the studied vocabulary visually anchored in both languages.
private struct ContextualSentenceCard: View {
    let example: ContextualSentence
    let chineseVocabulary: String
    let englishMeaning: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            highlightedChineseSentence
                .foregroundStyle(TingXiePalette.onBackground)
                .lineSpacing(4)

            if !example.english.isEmpty {
                highlightedEnglishSentence
                    .foregroundStyle(TingXiePalette.onBackground)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(TingXiePalette.outlineVariant.opacity(0.65), lineWidth: 1)
        }
    }

    private var highlightedChineseSentence: Text {
        highlightedText(
            example.chinese,
            term: chineseVocabulary,
            size: 18
        )
    }

    private var highlightedEnglishSentence: Text {
        let recordedTerm = example.englishVocabulary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let recordedTerm, !recordedTerm.isEmpty {
            return highlightedText(example.english, term: recordedTerm, size: 14)
        }

        let matchingTerm = englishMeaningCandidates.first {
            example.english.localizedCaseInsensitiveContains($0)
        }
        return highlightedText(
            example.english,
            term: matchingTerm ?? "",
            size: 14
        )
    }

    private var englishMeaningCandidates: [String] {
        englishMeaning
            .components(separatedBy: CharacterSet(charactersIn: ";,/|"))
            .flatMap { rawTerm -> [String] in
                let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !term.isEmpty else { return [] }
                let prefixes = ["to ", "a ", "an ", "the "]
                if let prefix = prefixes.first(where: {
                    term.lowercased().hasPrefix($0)
                }) {
                    return [term, String(term.dropFirst(prefix.count))]
                }
                return [term]
            }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    private func highlightedText(
        _ text: String,
        term: String,
        size: CGFloat
    ) -> Text {
        let regularFont = Font.system(size: size, weight: .regular)
        let boldFont = Font.system(size: size, weight: .bold)
        guard !term.isEmpty else { return Text(text).font(regularFont) }
        var remainder = text[...]
        var result = Text("")
        var foundMatch = false

        while let range = remainder.range(of: term, options: .caseInsensitive) {
            foundMatch = true
            result = result
                + Text(String(remainder[..<range.lowerBound])).font(regularFont)
            result = result
                + Text(String(remainder[range])).font(boldFont)
            remainder = remainder[range.upperBound...]
        }

        guard foundMatch else { return Text(text).font(regularFont) }
        return result + Text(String(remainder)).font(regularFont)
    }
}

// Standardizes headings within the vocabulary inspector.
private struct InspectorSectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(TingXieTypography.eyebrow)
            .tracking(0.15)
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
            .font(.system(size: compact ? 9 : 10, weight: .bold))
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
                    .font(.system(size: 23, weight: .semibold))
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
    let featuredWord = VocabularyWord(
        chinese: "把握", englishTranslation: "to grasp", pinyin: "bǎ wò", tags: [setTitle]
    )
    featuredWord.generatedSentence = """
    {"examples":[{"chinese":"你要好好把握这个难得的机会。","english":"You should really grasp this rare opportunity.","englishVocabulary":"grasp"},{"chinese":"他对这次考试很有把握。","english":"He is very certain about this exam.","englishVocabulary":"certain"}]}
    """
    let idiom = VocabularyWord(
        chinese: "莫名其妙", englishTranslation: "Baffling; without rhyme or reason",
        pinyin: "mò míng qí miào", isMissedWord: true, isIdiom: true, tags: [setTitle]
    )
    idiom.generatedSentence = "他今天突然朝我发脾气，真是莫名其妙。"
    let words = [
        featuredWord,
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
