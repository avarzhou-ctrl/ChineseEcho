import AppKit
import AVFoundation
import SwiftData
import SwiftUI

// Drives dictation-set search, list actions, practice presentation, and editor sheets.
struct SmartDictationView: View {
    @Environment(\.modelContext) private var modelContext

    let sets: [DictationSet]
    let activeSet: DictationSet?
    let onCreateSet: () -> Void
    let onOpenVocabulary: () -> Void
    let onOpenSet: (DictationSet) -> Void
    let onCloseSet: () -> Void

    @State private var searchText = ""
    @State private var isSearchResultsPresented = false
    @State private var highlightedSearchSetID: PersistentIdentifier?
    @State private var editingSet: DictationSet?
    @State private var setPendingDeletion: DictationSet?
    @State private var operationError: String?

    private var filteredSets: [DictationSet] {
        let query = searchText.tingXieTrimmed
        guard !query.isEmpty else { return sets }
        return sets.filter { set in
            SearchText.matches(set.title, query: query)
                || set.vocabularyWords.contains { word in
                    SearchText.matches(word.chinese, query: query)
                        || SearchText.matchesPinyin(word.pinyin, query: query)
                        || SearchText.matches(word.englishTranslation, query: query)
                }
        }
    }

    private var searchResultsOverlay: AnyView {
        AnyView(
            SearchResultsPanel(
                resultCount: filteredSets.count,
                emptyMessage: "No matching dictation sets",
                onClear: clearSearch
            ) {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredSets) { set in
                            DictationSearchResultRow(
                                set: set,
                                query: searchText.tingXieTrimmed,
                                isHighlighted: highlightedSearchSetID == set.persistentModelID,
                                onHover: { highlightedSearchSetID = set.persistentModelID },
                                onSelect: { openSearchResult(set) }
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
        Group {
            if let activeSet {
                PracticeSessionView(set: activeSet, onFinish: onCloseSet)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        WorkspaceHeader(
                            title: "Smart Dictation",
                            searchText: $searchText,
                            searchPrompt: "Search sets or vocabulary…",
                            searchAccessibilityLabel: "Search dictation sets and vocabulary",
                            searchResults: searchResultsOverlay,
                            searchResultsPresented: $isSearchResultsPresented,
                            onSearchSubmit: openHighlightedSearchResult,
                            onMoveSearchSelection: moveSearchSelection,
                            info: WorkspaceInfo(
                                title: "About Smart Dictation",
                                symbol: "waveform",
                                summary: "Build focused listening sets, practice them with native Mandarin speech, and collect the words that need more review.",
                                tips: [
                                    "Use the floating plus button to enter Chinese words, then let the local AI fill in pinyin and English translations.",
                                    "During practice, select the card or press Return to flip it and check the characters.",
                                    "Flag difficult words as missed; they will appear in the Vocabulary Hub for focused review."
                                ]
                            )
                        )

                        ScrollView {
                            VStack(alignment: .leading, spacing: 30) {
                                DictationHero(onOpenVocabulary: onOpenVocabulary)

                                DictationSetCollection(
                                    sets: sets,
                                    isSearching: false,
                                    onCreateSet: onCreateSet,
                                    onOpenSet: onOpenSet,
                                    onEditSet: { editingSet = $0 },
                                    onDuplicateSet: duplicateSet,
                                    onDeleteSet: { setPendingDeletion = $0 }
                                )

                                DictationLearningMetrics(sets: sets)
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 96)
                        }
                        .onTapGesture { isSearchResultsPresented = false }
                    }

                    Button(action: onCreateSet) {
                        Image(systemName: "plus")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(TingXiePalette.accent, in: Circle())
                            .shadow(color: TingXiePalette.accent.opacity(0.28), radius: 16, y: 8)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Create New Set")
                    .accessibilityLabel("Create New Set")
                    .padding(.trailing, 32)
                    .padding(.bottom, 30)
                }
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onChange(of: searchText) { _, _ in
            highlightedSearchSetID = filteredSets.first?.persistentModelID
            isSearchResultsPresented = !searchText.tingXieTrimmed.isEmpty
        }
        .sheet(item: $editingSet) { set in
            let setID = set.persistentModelID
            let initialTitle = set.title
            let initialWords = set.vocabularyWords.map { NewVocabularyWord($0) }

            NewDictationSetSheet(
                mode: .edit,
                modelContainer: modelContext.container,
                setID: setID,
                initialTitle: initialTitle,
                initialWords: initialWords
            )
        }
        .alert(
            "Delete “\(setPendingDeletion?.title ?? "Set")”?",
            isPresented: Binding(
                get: { setPendingDeletion != nil },
                set: { if !$0 { setPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { setPendingDeletion = nil }
            Button("Delete", role: .destructive) { deletePendingSet() }
        } message: {
            Text("This permanently removes the set and its saved vocabulary.")
        }
        .alert(
            "Couldn’t Update Set",
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

    private func duplicateSet(_ set: DictationSet) {
        let setID = set.persistentModelID
        Task {
            do {
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.duplicateSet(setID: setID)
            } catch {
                operationError = error.localizedDescription
            }
        }
    }

    private func clearSearch() {
        searchText = ""
        isSearchResultsPresented = false
        highlightedSearchSetID = nil
    }

    private func openSearchResult(_ set: DictationSet) {
        clearSearch()
        onOpenSet(set)
    }

    private func openHighlightedSearchResult() {
        guard !filteredSets.isEmpty else { return }
        let set = filteredSets.first {
            $0.persistentModelID == highlightedSearchSetID
        } ?? filteredSets[0]
        openSearchResult(set)
    }

    private func moveSearchSelection(_ direction: Int) {
        guard !filteredSets.isEmpty else {
            highlightedSearchSetID = nil
            return
        }
        let currentIndex = filteredSets.firstIndex {
            $0.persistentModelID == highlightedSearchSetID
        } ?? (direction > 0 ? -1 : 0)
        let nextIndex = min(max(currentIndex + direction, 0), filteredSets.count - 1)
        highlightedSearchSetID = filteredSets[nextIndex].persistentModelID
    }

    private func deletePendingSet() {
        guard let setPendingDeletion else { return }
        let setID = setPendingDeletion.persistentModelID
        self.setPendingDeletion = nil
        Task {
            do {
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.deleteSet(setID: setID)
            } catch {
                operationError = error.localizedDescription
            }
        }
    }
}

// Summarizes persistent practice outcomes across all dictation sets.
private struct DictationLearningMetrics: View {
    let sets: [DictationSet]

    @State private var analytics = PracticeAnalyticsSnapshot.empty

    private var vocabularyKeys: Set<String> {
        Set(sets.flatMap(\.vocabularyWords).map(Self.vocabularyKey))
    }

    private var masteredVocabulary: Set<String> {
        analytics.masteredVocabulary.intersection(vocabularyKeys)
    }

    private var charactersLearned: Int {
        Set(
            masteredVocabulary
                .joined()
                .unicodeScalars
                .filter(Self.isHanCharacter)
        ).count
    }

    var body: some View {
        HStack(spacing: 18) {
            LearningMetricCard(
                title: "Study Streak",
                value: "\(analytics.studyStreak)",
                detail: analytics.studyStreak == 1 ? "Day" : "Days",
                symbol: "flame.fill"
            )
            LearningMetricCard(
                title: "Characters Learned",
                value: "\(charactersLearned)",
                detail: "characters",
                symbol: "character.book.closed.fill"
            )
            LearningMetricCard(
                title: "Accuracy",
                value: analytics.accuracy.map { ($0 * 100).formatted(.number.precision(.fractionLength(1))) } ?? "—",
                detail: analytics.totalAttempts == 0 ? "No attempts yet" : "%",
                symbol: "target"
            )
        }
        .onAppear(perform: refreshAnalytics)
        .onReceive(NotificationCenter.default.publisher(for: .practiceAnalyticsDidChange)) { _ in
            refreshAnalytics()
        }
    }

    private func refreshAnalytics() {
        analytics = PracticeAnalyticsStore.snapshot()
    }

    nonisolated private static func vocabularyKey(_ word: VocabularyWord) -> String {
        word.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func isHanCharacter(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x4DBF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value)
            || (0x20000...0x2FA1F).contains(scalar.value)
    }
}

// Keeps the three headline learning signals visually equal at flexible window widths.
private struct LearningMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(TingXieTypography.eyebrow)
                    .tracking(0.15)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.68))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value)
                        .font(TingXieTypography.learningValue)
                        .foregroundStyle(TingXiePalette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(TingXiePalette.secondary.opacity(0.2))
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 112)
        .tonalCard(fill: TingXiePalette.lightGreenSurface)
    }
}

// Summarizes one matching set and the vocabulary field that satisfied the search.
private struct DictationSearchResultRow: View {
    let set: DictationSet
    let query: String
    let isHighlighted: Bool
    let onHover: () -> Void
    let onSelect: () -> Void

    private var matchingWord: VocabularyWord? {
        self.set.vocabularyWords.first { word in
            SearchText.matches(word.chinese, query: query)
                || SearchText.matchesPinyin(word.pinyin, query: query)
                || SearchText.matches(word.englishTranslation, query: query)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 32, height: 32)
                    .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 4) {
                    Text(set.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TingXiePalette.onBackground)
                        .lineLimit(1)

                    if let matchingWord {
                        Text("Match: \(matchingWord.chinese)  ·  \(matchingWord.pinyin)")
                            .lineLimit(1)
                    } else {
                        Text("\(set.vocabularyWords.count) vocabulary words")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 56)
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
        .accessibilityLabel("Open \(set.title), \(set.vocabularyWords.count) vocabulary words")
    }
}

// Introduces the dictation workspace and links learners to saved vocabulary.
private struct DictationHero: View {
    let onOpenVocabulary: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Master your listening with focused audio drills.")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(maxWidth: 480, alignment: .leading)

                Text("Build a custom set from the Chinese you are learning, then listen, flip, and review at your own pace.")
                    .font(.system(size: 15))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .lineSpacing(3)
                    .frame(maxWidth: 510, alignment: .leading)
                    .padding(.top, 12)

                HStack(spacing: 12) {
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

// Switches between the empty state and the learner's saved set list.
private struct DictationSetCollection: View {
    let sets: [DictationSet]
    let isSearching: Bool
    let onCreateSet: () -> Void
    let onOpenSet: (DictationSet) -> Void
    let onEditSet: (DictationSet) -> Void
    let onDuplicateSet: (DictationSet) -> Void
    let onDeleteSet: (DictationSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Dictation Practice")
                .font(TingXieTypography.sectionTitle)

            if sets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: isSearching ? "magnifyingglass" : "waveform.badge.plus")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(TingXiePalette.secondary.opacity(0.7))
                    Text(isSearching ? "No matching sets" : "No Sessions Yet")
                        .font(TingXieTypography.sectionTitle)
                    Text(isSearching ? "Try a different set name or vocabulary word." : "Create your first custom practice round to start testing your vocabulary.")
                        .font(TingXieTypography.body)
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                    if !isSearching {
                        Button("Create New Set", systemImage: "plus", action: onCreateSet)
                            .buttonStyle(GreenCapsuleButtonStyle())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, minHeight: 180)
                .tonalCard(fill: TingXiePalette.lightGreenSurface)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sets) { set in
                        DictationSetRow(
                            set: set,
                            onOpen: { onOpenSet(set) },
                            onEdit: { onEditSet(set) },
                            onDuplicate: { onDuplicateSet(set) },
                            onDelete: { onDeleteSet(set) }
                        )
                    }
                }
            }
        }
    }
}

// Renders one set with practice, edit, duplicate, and delete actions.
private struct DictationSetRow: View {
    let set: DictationSet
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var analytics = PracticeAnalyticsSnapshot.empty

    private var vocabularyKeys: Set<String> {
        Set(
            set.vocabularyWords.map {
                $0.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
    }

    private var progress: Double {
        guard !vocabularyKeys.isEmpty else { return 0 }
        let masteredCount = analytics.masteredVocabulary.intersection(vocabularyKeys).count
        return Double(masteredCount) / Double(vocabularyKeys.count)
    }

    private var isCompleted: Bool {
        !vocabularyKeys.isEmpty && progress >= 1
    }

    private var progressStatusText: String {
        if isCompleted { return "Completed" }
        return "Progress: \(progress.formatted(.percent.precision(.fractionLength(0))))"
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 18) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(TingXiePalette.accent)
                        .frame(width: 52, height: 52)
                        .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(set.title)
                            .font(.system(size: 18, weight: .medium))
                        HStack(spacing: 12) {
                            Label(set.dateCreated.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            Label("\(set.vocabularyWords.count) words", systemImage: "list.bullet")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.72))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        ProgressView(value: progress)
                            .tint(TingXiePalette.accent)
                            .frame(width: 132)

                        Text(progressStatusText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                isCompleted
                                    ? TingXiePalette.secondary
                                    : TingXiePalette.onSurfaceVariant.opacity(0.72)
                            )
                            .monospacedDigit()
                    }
                    .fixedSize()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Learning progress")
                    .accessibilityValue(progressStatusText)
                    .padding(.trailing, 32)
                    .offset(y: 9)
                }
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, minHeight: 96)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Rename or Edit Words", systemImage: "pencil", action: onEdit)
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .frame(width: 60, height: 56, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.trailing, 20)
            .help("Edit \(set.title)")
            .accessibilityLabel("Edit \(set.title)")
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .tonalCard(fill: TingXiePalette.lightGreenSurface)
        .onAppear(perform: refreshAnalytics)
        .onReceive(NotificationCenter.default.publisher(for: .practiceAnalyticsDidChange)) { _ in
            refreshAnalytics()
        }
    }

    private func refreshAnalytics() {
        analytics = PracticeAnalyticsStore.snapshot()
    }
}

// Defines whether a practice session includes every word or only missed words.
private enum PracticeFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }
}

// Captures the persisted word state needed to reverse one grading decision.
private struct PracticeGradeAction {
    let wordID: PersistentIdentifier
    let queueIndex: Int
    let wasMissed: Bool
    let markedMissed: Bool
    let vocabularyKey: String
    let previousMastery: Bool?
}

// Coordinates filtered practice progress, speech repetition, and missed-word updates.
private struct PracticeSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let set: DictationSet
    let onFinish: () -> Void

    @AppStorage(AppPreferenceKey.repeatCount)
    private var repeatCount = AppPreferenceDefault.repeatCount
    @AppStorage(AppPreferenceKey.keepCardsRevealed)
    private var keepCardsRevealed = AppPreferenceDefault.keepCardsRevealed

    @State private var filter: PracticeFilter = .all
    @State private var filterTransitionEdge: Edge = .trailing
    @State private var cardTransitionEdge: Edge = .trailing
    @State private var sessionWordIDs: [PersistentIdentifier] = []
    @State private var currentIndex = 0
    @State private var isCardFlipped = false
    @State private var remainingAutomaticRepetitions = 0
    @State private var missedOverrides: [PersistentIdentifier: Bool] = [:]
    @State private var gradeHistory: [PracticeGradeAction] = []
    @State private var isUpdatingGrade = false
    @State private var hasGradedCurrentCard = false
    @State private var hasInitializedQueue = false
    @State private var isQueueShuffled = false
    @State private var audioEngine = SpeechAudioEngine()

    private var filteredWords: [VocabularyWord] {
        switch filter {
        case .all: set.vocabularyWords
        case .missed: set.vocabularyWords.filter(isMissed)
        case .idioms: set.vocabularyWords.filter(\.isIdiom)
        }
    }

    private var currentWord: VocabularyWord? {
        guard sessionWordIDs.indices.contains(currentIndex) else { return nil }
        let wordID = sessionWordIDs[currentIndex]
        return set.vocabularyWords.first { $0.persistentModelID == wordID }
    }

    private var canGradeCurrentCard: Bool {
        isCardFlipped && !isUpdatingGrade && !hasGradedCurrentCard
    }

    private var canUndoLastGrade: Bool {
        !gradeHistory.isEmpty && (currentIndex > 0 || hasGradedCurrentCard) && !isUpdatingGrade
    }

    private var animatedFilter: Binding<PracticeFilter> {
        Binding(
            get: { filter },
            set: updateFilter
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Practice Session",
                info: WorkspaceInfo(
                    title: "About Practice Sessions",
                    symbol: "rectangle.on.rectangle.angled",
                    summary: "Listen first, then flip each card to check the characters before deciding whether the word needs more review.",
                    tips: [
                        "Select the card or press Return or Space to flip between the listening prompt and the answer.",
                        "The missed and known actions appear only after the answer is visible.",
                        "Each card plays automatically using the repeat count in Settings; use the speaker for one extra playback."
                    ]
                )
            )

            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Set")
                        .font(TingXieTypography.eyebrow)
                        .tracking(0.15)
                        .foregroundStyle(TingXiePalette.secondary)
                    Text(set.title)
                        .font(.system(size: 24, weight: .medium))
                }
                Spacer()
                PracticeFilterBar(selection: animatedFilter)
                    .frame(maxWidth: 430)
            }
            .padding(.horizontal, 40)

            Group {
                if !hasInitializedQueue {
                    ProgressView()
                } else if sessionWordIDs.isEmpty {
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
            audioEngine.configureFromPreferences()
            audioEngine.onUtteranceFinished = {
                Task { @MainActor in continueAutomaticPlayback() }
            }
            resetSessionQueue()
        }
        .onDisappear {
            stopPlayback()
            audioEngine.onUtteranceFinished = nil
        }
        .onChange(of: filter) { _, _ in
            resetSessionQueue()
        }
        .onChange(of: keepCardsRevealed) { _, shouldReveal in
            isCardFlipped = shouldReveal
        }
    }

    private var practiceContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            ZStack {
                VStack(spacing: 0) {
                    if let currentWord {
                HStack {
                    Button("Shuffle", systemImage: "shuffle", action: shuffleRemainingWords)
                        .help("Shuffle the current and remaining cards")
                        .disabled(sessionWordIDs.count - currentIndex < 2 || isUpdatingGrade)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isQueueShuffled
                                ? TingXiePalette.secondary.opacity(0.12)
                                : .clear,
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    isQueueShuffled ? TingXiePalette.secondary : .clear,
                                    lineWidth: 1.5
                                )
                        }
                        .animation(.easeOut(duration: 0.18), value: isQueueShuffled)

                    Spacer()

                    Button("Undo", systemImage: "arrow.uturn.backward", action: undoLastGrade)
                        .help("Undo the last grading decision")
                        .foregroundStyle(
                            canUndoLastGrade
                                ? TingXiePalette.onSurfaceVariant
                                : TingXiePalette.outline.opacity(0.55)
                        )
                        .disabled(!canUndoLastGrade)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .frame(maxWidth: 650)
                .padding(.bottom, 10)
                .offset(y: 32)

                ZStack(alignment: .topTrailing) {
                    PracticeFlipCard(
                        word: currentWord,
                        showsMissed: isMissed(currentWord),
                        isFlipped: $isCardFlipped,
                        reduceMotion: reduceMotion
                    )

                    Button(action: replayCurrentWord) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 38, height: 38)
                            .background(TingXiePalette.surfaceContainerHigh, in: Circle())
                            .overlay { Circle().stroke(TingXiePalette.outlineVariant, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TingXiePalette.accent)
                    .help("Play once more")
                    .accessibilityLabel("Play \(currentWord.chinese) once more")
                    .padding(20)
                }
                .frame(maxWidth: 650, minHeight: 300, maxHeight: 360)
                .id(currentWord.persistentModelID)
                .transition(
                    TingXieMotion.directionalTransition(
                        enteringFrom: cardTransitionEdge,
                        reduceMotion: reduceMotion
                    )
                )
                .animation(
                    TingXieMotion.contentChange(reduceMotion: reduceMotion),
                    value: currentWord.persistentModelID
                )
                .offset(y: 32)

                Text("Press Space or click the card to flip")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.68))
                    .frame(height: 18)
                    .opacity(isCardFlipped ? 0 : 1)
                    .accessibilityHidden(isCardFlipped)
                    .animation(.easeOut(duration: 0.18), value: isCardFlipped)
                    .padding(.top, 10)
                    .offset(y: 32)

                HStack(spacing: 30) {
                    PracticeGradeButton(
                        symbol: "xmark",
                        color: TingXiePalette.missed,
                        accessibilityLabel: "Mark Missed",
                        help: "Mark Missed (X)",
                        shortcut: "x"
                    ) {
                        gradeCurrentWord(asMissed: true)
                    }

                    PracticeGradeButton(
                        symbol: "checkmark",
                        color: TingXiePalette.secondary,
                        accessibilityLabel: "Mark Known",
                        help: "Mark Known (Right Arrow)",
                        shortcut: .rightArrow
                    ) {
                        gradeCurrentWord(asMissed: false)
                    }
                }
                .frame(height: 74)
                .opacity(canGradeCurrentCard ? 1 : 0)
                .allowsHitTesting(canGradeCurrentCard)
                .accessibilityHidden(!canGradeCurrentCard)
                .animation(.easeOut(duration: 0.18), value: canGradeCurrentCard)
                .padding(.top, 16)
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
            .animation(
                TingXieMotion.contentChange(reduceMotion: reduceMotion),
                value: filter
            )

            Spacer(minLength: 22)

            HStack(alignment: .bottom, spacing: 32) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Card \(min(currentIndex + 1, sessionWordIDs.count)) of \(sessionWordIDs.count)")
                        .font(.system(size: 13, weight: .semibold))
                    ProgressView(value: Double(currentIndex + 1), total: Double(max(sessionWordIDs.count, 1)))
                        .tint(TingXiePalette.accent)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Finish Set", systemImage: "rectangle.portrait.and.arrow.right", action: onFinish)
                    .buttonStyle(
                        OutlineCapsuleButtonStyle(
                            fontSize: 13,
                            horizontalPadding: 16,
                            height: 34
                        )
                    )
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

    private func updateFilter(_ newFilter: PracticeFilter) {
        guard newFilter != filter else { return }
        let filters = PracticeFilter.allCases
        let oldIndex = filters.firstIndex(of: filter) ?? 0
        let newIndex = filters.firstIndex(of: newFilter) ?? 0
        filterTransitionEdge = newIndex > oldIndex ? .trailing : .leading
        cardTransitionEdge = filterTransitionEdge
        filter = newFilter
    }

    private func resetSessionQueue() {
        stopPlayback()
        sessionWordIDs = filteredWords.map(\.persistentModelID)
        currentIndex = 0
        gradeHistory.removeAll()
        hasGradedCurrentCard = false
        hasInitializedQueue = true
        isQueueShuffled = false
        isCardFlipped = keepCardsRevealed
        scheduleAutomaticPlayback()
    }

    private func stopPlayback() {
        remainingAutomaticRepetitions = 0
        audioEngine.stop()
    }

    private func scheduleAutomaticPlayback() {
        Task { @MainActor in
            await Task.yield()
            startAutomaticPlayback()
        }
    }

    private func startAutomaticPlayback() {
        guard currentWord != nil else { return }
        audioEngine.stop()
        remainingAutomaticRepetitions = max(repeatCount, 1)
        speakNextAutomaticRepetition()
    }

    private func speakNextAutomaticRepetition() {
        guard remainingAutomaticRepetitions > 0 else { return }
        remainingAutomaticRepetitions -= 1
        speakCurrentWord()
    }

    private func continueAutomaticPlayback() {
        guard remainingAutomaticRepetitions > 0 else { return }
        speakNextAutomaticRepetition()
    }

    private func replayCurrentWord() {
        stopPlayback()
        speakCurrentWord()
    }

    private func shuffleRemainingWords() {
        guard sessionWordIDs.count - currentIndex > 1 else { return }
        stopPlayback()
        cardTransitionEdge = .trailing
        sessionWordIDs.replaceSubrange(
            currentIndex..<sessionWordIDs.endIndex,
            with: sessionWordIDs[currentIndex...].shuffled()
        )
        isQueueShuffled = true
        hasGradedCurrentCard = false
        isCardFlipped = false
        scheduleAutomaticPlayback()
    }

    private func gradeCurrentWord(asMissed: Bool) {
        guard canGradeCurrentCard, let currentWord else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        let wordID = currentWord.persistentModelID
        let action = PracticeGradeAction(
            wordID: wordID,
            queueIndex: currentIndex,
            wasMissed: isMissed(currentWord),
            markedMissed: asMissed,
            vocabularyKey: currentWord.chinese.tingXieTrimmed,
            previousMastery: PracticeAnalyticsStore.masteryState(
                for: currentWord.chinese.tingXieTrimmed
            )
        )
        isUpdatingGrade = true
        stopPlayback()

        Task {
            do {
                try await store.setMissed(asMissed, wordID: wordID)
                missedOverrides[wordID] = asMissed
                PracticeAnalyticsStore.recordResult(
                    isCorrect: !asMissed,
                    vocabularyKey: action.vocabularyKey
                )
                gradeHistory.append(action)
                hasGradedCurrentCard = true

                if currentIndex < sessionWordIDs.count - 1 {
                    cardTransitionEdge = .trailing
                    currentIndex += 1
                    hasGradedCurrentCard = false
                    isCardFlipped = keepCardsRevealed
                    scheduleAutomaticPlayback()
                }
            } catch {
                // Keep the current card available when persistence fails.
            }
            isUpdatingGrade = false
        }
    }

    private func undoLastGrade() {
        guard !isUpdatingGrade, let action = gradeHistory.last else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        isUpdatingGrade = true
        stopPlayback()

        Task {
            do {
                try await store.setMissed(action.wasMissed, wordID: action.wordID)
                missedOverrides[action.wordID] = action.wasMissed
                PracticeAnalyticsStore.undoResult(
                    isCorrect: !action.markedMissed,
                    vocabularyKey: action.vocabularyKey,
                    restoringMastery: action.previousMastery
                )
                gradeHistory.removeLast()
                cardTransitionEdge = .leading
                currentIndex = min(action.queueIndex, max(sessionWordIDs.count - 1, 0))
                hasGradedCurrentCard = false
                isCardFlipped = false
                scheduleAutomaticPlayback()
            } catch {
                // Leave history intact so Undo can be retried.
            }
            isUpdatingGrade = false
        }
    }

    private func isMissed(_ word: VocabularyWord) -> Bool {
        missedOverrides[word.persistentModelID] ?? word.isMissedWord
    }
}

// Presents the full-set and missed-only practice modes as a compact segmented control.
private struct PracticeFilterBar: View {
    @Binding var selection: PracticeFilter

    var body: some View {
        SlidingFilterBar(
            items: PracticeFilter.allCases,
            selection: $selection,
            title: \.rawValue
        )
    }
}

// Flips between an audio-first prompt and the complete vocabulary answer.
private struct PracticeFlipCard: View {
    let word: VocabularyWord
    let showsMissed: Bool
    @Binding var isFlipped: Bool
    let reduceMotion: Bool

    var body: some View {
        Button(action: flip) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(TingXiePalette.lightGreenSurface)

                cardFace(isAnswer: false)
                    .opacity(isFlipped ? 0 : 1)

                cardFace(isAnswer: true)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 28))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.8), lineWidth: 1) }
            .shadow(color: TingXiePalette.accent.opacity(0.11), radius: 28, y: 16)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
        .accessibilityLabel(isFlipped ? "Hide answer for \(word.chinese)" : "Show answer")
        .accessibilityHint("Flips the practice card")
        .overlay {
            Button("Flip Card", action: flip)
                .keyboardShortcut(.space, modifiers: [])
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private func cardFace(isAnswer: Bool) -> some View {
        VStack(spacing: 18) {
            if isAnswer {
                Text(word.chinese)
                    .font(TingXieTypography.vocabulary(size: word.chinese.count > 4 ? 48 : 64, weight: .bold))
                    .foregroundStyle(showsMissed ? TingXiePalette.missed : TingXiePalette.accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)

                Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                    .font(.system(size: 15))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.78))
            } else {
                Text(word.pinyin.isEmpty ? "Listen carefully" : word.pinyin)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(TingXiePalette.accent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func flip() {
        if reduceMotion {
            isFlipped.toggle()
        } else {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                isFlipped.toggle()
            }
        }
    }
}

// Presents one icon-only grading action while retaining tooltip and accessibility context.
private struct PracticeGradeButton: View {
    let symbol: String
    let color: Color
    let accessibilityLabel: String
    let help: String
    let shortcut: KeyEquivalent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(color.opacity(0.06), in: Circle())
                .overlay { Circle().stroke(color.opacity(0.32), lineWidth: 1.5) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: [])
        .help(help)
        .accessibilityLabel(accessibilityLabel)
    }
}

// Supplies create-versus-edit titles and primary action labels to the shared editor.
enum DictationSetEditorMode {
    case create
    case edit

    var title: String {
        switch self {
        case .create: "Create New Set"
        case .edit: "Edit Dictation Set"
        }
    }

    var actionTitle: String {
        switch self {
        case .create: "Create Set"
        case .edit: "Save Changes"
        }
    }
}

// Holds mutable editor fields until they are validated into a save payload.
private struct DraftVocabularyWord: Identifiable {
    let id: UUID
    var chinese: String
    var pinyin: String
    var translation: String
    var isIdiom: Bool

    init(
        id: UUID = UUID(),
        chinese: String = "",
        pinyin: String = "",
        translation: String = "",
        isIdiom: Bool = false
    ) {
        self.id = id
        self.chinese = chinese
        self.pinyin = pinyin
        self.translation = translation
        self.isIdiom = isIdiom
    }

    init(_ word: NewVocabularyWord) {
        self.init(
            chinese: word.chinese,
            pinyin: word.pinyin,
            translation: word.translation,
            isIdiom: word.isIdiom
        )
    }

    var savedValue: NewVocabularyWord? {
        let cleanChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChinese.isEmpty else { return nil }
        return NewVocabularyWord(
            chinese: cleanChinese,
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            isIdiom: isIdiom
        )
    }
}

// Builds or edits a set through dictionary lookup, Local AI fallback, import, and review.
@MainActor
struct NewDictationSetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: DictationSetEditorMode
    let modelContainer: ModelContainer
    let setID: PersistentIdentifier?

    @State private var title: String
    @State private var chineseWordInput = ""
    @State private var manualText = ""
    @State private var draftWords: [DraftVocabularyWord]
    @State private var errorMessage: String?
    @State private var initialModelOutput = ""
    @State private var repairModelOutput = ""
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var modelDownloadCoordinator = ModelDownloadCoordinator.shared

    init(
        mode: DictationSetEditorMode = .create,
        modelContainer: ModelContainer,
        setID: PersistentIdentifier? = nil,
        initialTitle: String = "",
        initialWords: [NewVocabularyWord] = []
    ) {
        self.mode = mode
        self.modelContainer = modelContainer
        self.setID = setID
        _title = State(initialValue: initialTitle)
        _draftWords = State(initialValue: initialWords.map { DraftVocabularyWord($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "character.book.closed")
                    .foregroundStyle(TingXiePalette.accent)
                Text(mode.title)
                    .font(.system(size: 24, weight: .medium))
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

            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text("Set Name")
                                    .font(.system(size: 13, weight: .semibold))
                                if let errorMessage {
                                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(TingXiePalette.missed)
                                        .lineLimit(1)
                                        .help(errorMessage)
                                }
                            }
                            TextField("e.g., Travel essentials", text: $title)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 9))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Fill Vocabulary Details", systemImage: "text.book.closed")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(TingXiePalette.accent)

                            Text("Enter Chinese words separated by commas, spaces, or new lines.")
                                .font(.system(size: 12))
                                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                .lineSpacing(2)

                            TextEditor(text: $chineseWordInput)
                                .font(.system(size: 13))
                                .scrollContentBackground(.hidden)
                                .padding(9)
                                .frame(minHeight: 110)
                                .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityLabel("Chinese words to enrich")

                            HStack {
                                Text("Example: 苹果, 学习, 坚持")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                Spacer()
                                Button(action: enrichChineseWords) {
                                    if modelDownloadCoordinator.phase == .downloading {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text(modelDownloadCoordinator.percentageText)
                                        }
                                    } else if modelDownloadCoordinator.isPreparing {
                                        Label("Preparing AI", systemImage: "cpu")
                                    } else if isGenerating {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Label("Fill Details", systemImage: "wand.and.stars")
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                }
                                .buttonStyle(
                                    OutlineCapsuleButtonStyle(
                                        fontSize: 12,
                                        horizontalPadding: 12,
                                        height: 32
                                    )
                                )
                                .disabled(
                                    inputChineseWords.isEmpty
                                        || isGenerating
                                        || modelDownloadCoordinator.isPreparing
                                )
                            }
                        }
                        .padding(16)
                        .background(TingXiePalette.surfaceContainer.opacity(0.62), in: RoundedRectangle(cornerRadius: 14))

                        modelOutputPanel

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manual Import")
                                .font(.system(size: 13, weight: .semibold))
                            TextEditor(text: $manualText)
                                .font(.system(size: 12, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 90)
                                .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 9))
                            HStack {
                                Text("One per line: Chinese | pinyin | translation")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                Spacer()
                                Button("Import Lines", systemImage: "square.and.arrow.down", action: importManualLines)
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TingXiePalette.accent)
                                    .disabled(manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                    }
                    .padding(24)
                }
                .frame(minWidth: 320, idealWidth: 350)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Review Words")
                                .font(.system(size: 16, weight: .bold))
                            Text("\(validWords.count) ready to save")
                                .font(.system(size: 11))
                                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        }
                        Spacer()
                        Button("Add Word", systemImage: "plus", action: addBlankWord)
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TingXiePalette.accent)
                    }

                    Divider()

                    if draftWords.isEmpty {
                        ContentUnavailableView(
                            "No Words Yet",
                            systemImage: "text.badge.plus",
                            description: Text("Generate suggestions, import lines, or add a word manually.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach($draftWords) { $word in
                                    DraftVocabularyRow(
                                        word: $word,
                                        canMoveUp: word.id != draftWords.first?.id,
                                        canMoveDown: word.id != draftWords.last?.id,
                                        onMoveUp: { moveWord(id: word.id, by: -1) },
                                        onMoveDown: { moveWord(id: word.id, by: 1) },
                                        onDelete: { deleteWord(id: word.id) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(minWidth: 440, idealWidth: 500)
            }

            Divider().overlay(TingXiePalette.outlineVariant.opacity(0.5))

            HStack(spacing: 14) {
                Text("Dictionary lookups and AI fallbacks stay on this Mac and are always reviewed before saving.")
                    .font(.system(size: 10))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(TingXiePalette.accent)
                Button(action: save) {
                    Label(isSaving ? "Saving…" : mode.actionTitle, systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(GreenCapsuleButtonStyle())
                .disabled(isSaving)
            }
            .padding(.horizontal, 28)
            .frame(height: 76)
            .background(TingXiePalette.surfaceContainer.opacity(0.65))
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(.ultraThinMaterial)
        .background(TingXiePalette.lightGreenSurface.opacity(0.84))
        .frame(width: 900, height: 680)
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var inputChineseWords: [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",，、;；"))
        var seen = Set<String>()
        return chineseWordInput
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { word in
                !word.isEmpty
                    && word.range(of: "\\p{Han}", options: .regularExpression) != nil
                    && seen.insert(word).inserted
            }
    }

    private var validWords: [NewVocabularyWord] {
        draftWords.compactMap(\.savedValue)
    }

    private var saveValidationMessage: String? {
        if cleanTitle.isEmpty {
            return "Enter a set name before saving."
        }
        if validWords.isEmpty {
            return "Add at least one word before saving."
        }
        if isGenerating {
            return "Wait for Fill Details to finish before saving."
        }
        return nil
    }

    @ViewBuilder
    private var modelOutputPanel: some View {
        if !initialModelOutput.isEmpty || !repairModelOutput.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Model Output", systemImage: "text.bubble")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TingXiePalette.accent)
                    Spacer()
                    Button("Copy", systemImage: "doc.on.doc", action: copyModelOutput)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TingXiePalette.accent)
                }

                modelOutputSection(title: "Initial response", text: initialModelOutput)

                if !repairModelOutput.isEmpty {
                    Divider()
                    modelOutputSection(title: "Repair response", text: repairModelOutput)
                }
            }
            .padding(14)
            .background(TingXiePalette.surfaceContainer.opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(TingXiePalette.outlineVariant.opacity(0.65), lineWidth: 1)
            }
        }
    }

    private func modelOutputSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
            ScrollView {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(TingXiePalette.onBackground)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 150)
            .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func copyModelOutput() {
        let sections = [
            initialModelOutput.isEmpty ? nil : "Initial response:\n\(initialModelOutput)",
            repairModelOutput.isEmpty ? nil : "Repair response:\n\(repairModelOutput)"
        ].compactMap { $0 }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sections.joined(separator: "\n\n"), forType: .string)
    }

    private func addBlankWord() {
        draftWords.append(DraftVocabularyWord())
    }

    private func moveWord(id: UUID, by offset: Int) {
        guard let index = draftWords.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard draftWords.indices.contains(index), draftWords.indices.contains(destination) else { return }
        draftWords.swapAt(index, destination)
    }

    private func deleteWord(id: UUID) {
        draftWords.removeAll { $0.id == id }
    }

    private func importManualLines() {
        let imported = parseVocabularyLines(manualText)
        guard !imported.isEmpty else {
            errorMessage = "No valid lines were found. Separate each field with a vertical bar."
            return
        }
        draftWords.append(contentsOf: imported)
        manualText = ""
        errorMessage = nil
    }

    private func enrichChineseWords() {
        let words = inputChineseWords
        guard !words.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        initialModelOutput = ""
        repairModelOutput = ""

        Task {
            do {
                let dictionaryEntries = (try? await CCCEDICTDictionary.shared.entries(for: words)) ?? [:]
                let unresolvedWords = words.filter { dictionaryEntries[$0] == nil }
                var enrichedByWord = Dictionary(
                    uniqueKeysWithValues: dictionaryEntries.map { word, entry in
                        (
                            word,
                            DraftVocabularyWord(
                                chinese: word,
                                pinyin: entry.pinyin,
                                translation: entry.translation,
                                isIdiom: word.count == 4
                            )
                        )
                    }
                )

                if !unresolvedWords.isEmpty {
                    let prompt = vocabularyEnrichmentPrompt(for: unresolvedWords)
                    let response = try await generateText(prompt: prompt)
                    initialModelOutput = response
                    var generated = orderedEnrichment(
                        parseVocabularyLines(response, usesSystemPinyin: true),
                        matching: unresolvedWords
                    )

                    if generated.count != unresolvedWords.count {
                        let repairedResponse = try await generateText(
                            prompt: vocabularyRepairPrompt(
                                for: response,
                                words: unresolvedWords
                            )
                        )
                        repairModelOutput = repairedResponse
                        generated = orderedEnrichment(
                            parseVocabularyLines(
                                repairedResponse,
                                usesSystemPinyin: true
                            ),
                            matching: unresolvedWords
                        )
                    }

                    guard generated.count == unresolvedWords.count else {
                        throw VocabularyGenerationError.invalidResponse
                    }
                    for entry in generated {
                        enrichedByWord[entry.chinese] = entry
                    }
                }

                let generated = words.compactMap { enrichedByWord[$0] }
                guard generated.count == words.count else {
                    throw VocabularyGenerationError.invalidResponse
                }
                draftWords = generated
            } catch {
                errorMessage = friendlyGenerationMessage(for: error)
            }
            isGenerating = false
        }
    }

    private func parseVocabularyLines(
        _ text: String,
        usesSystemPinyin: Bool = false
    ) -> [DraftVocabularyWord] {
        text
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let line = String(rawLine)
                    .replacingOccurrences(of: "｜", with: "|")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "`*-0123456789.、) \t"))
                let fields = line.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard fields.count >= 3 else { return nil }
                let chinese = fields[0]
                let suppliedPinyin = fields[1]
                let translation = fields.dropFirst(2).joined(separator: " | ")
                guard chinese.range(of: "\\p{Han}", options: .regularExpression) != nil,
                      translation.range(of: "[A-Za-z]", options: .regularExpression) != nil else {
                    return nil
                }
                let pinyin = usesSystemPinyin
                    ? systemPinyin(for: chinese) ?? suppliedPinyin
                    : suppliedPinyin
                return DraftVocabularyWord(
                    chinese: chinese,
                    pinyin: pinyin,
                    translation: translation,
                    isIdiom: chinese.count == 4
                )
            }
    }

    private func orderedEnrichment(
        _ generated: [DraftVocabularyWord],
        matching words: [String]
    ) -> [DraftVocabularyWord] {
        words.compactMap { word in
            generated.first {
                $0.chinese.trimmingCharacters(in: .whitespacesAndNewlines) == word
            }
        }
    }

    private func vocabularyEnrichmentPrompt(for words: [String]) -> String {
        """
        Add pinyin and a concise English translation for every Chinese word below. Preserve the exact Chinese text and order. Do not add, remove, combine, or replace words.

        <chinese_words>
        \(words.joined(separator: "\n"))
        </chinese_words>

        Return only one entry per line in this exact format:
        Chinese | pinyin with tone marks | concise English translation

        Return exactly \(words.count) lines. Do not number the lines or add a heading, explanation, markdown, or code fence.
        """
    }

    private func vocabularyRepairPrompt(for response: String, words: [String]) -> String {
        """
        Correct the candidate output so it contains one entry for every supplied Chinese word in the exact same order. Do not add, remove, combine, or replace words.

        <chinese_words>
        \(words.joined(separator: "\n"))
        </chinese_words>

        Return only one entry per line in this exact format:
        Chinese | pinyin with tone marks | concise English translation

        Return exactly \(words.count) lines. Every third field must contain an English definition. Do not number the lines or add any other text.

        <candidate_output>
        \(response)
        </candidate_output>
        """
    }

    private func systemPinyin(for chinese: String) -> String? {
        chinese
            .applyingTransform(.mandarinToLatin, reverse: false)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func friendlyGenerationMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           urlError.code == .cannotConnectToHost || urlError.code == .networkConnectionLost {
            return "The local model could not be downloaded. Check your connection, or use Manual Import."
        }
        return error.localizedDescription
    }

    @MainActor
    private func save() {
        if let saveValidationMessage {
            errorMessage = saveValidationMessage
            return
        }

        let request = DictationSetSaveRequest(
            destination: setID.map(DictationSetSaveRequest.Destination.existing)
                ?? .new,
            title: cleanTitle,
            words: validWords
        )
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let store = DictationStore(modelContainer: modelContainer)
                let generationTargets = try await store.saveSet(request)
                dismiss()
                Task { @MainActor in
                    await ContextualSentenceGenerator.generateAndStore(
                        targets: generationTargets,
                        modelContainer: modelContainer
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

// Reports Local AI output that cannot be reconciled with the requested words.
private enum VocabularyGenerationError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "The model could not fill details for every Chinese word. Check the input and try again, or use Manual Import."
    }
}

// Edits and reorders one vocabulary draft in the set review column.
private struct DraftVocabularyRow: View {
    @Binding var word: DraftVocabularyWord
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Chinese", text: $word.chinese)
                    .font(.system(size: 18, weight: .semibold))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 90)

                Toggle("Idiom", isOn: $word.isIdiom)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))

                Spacer()

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.plain)

            TextField("Pinyin", text: $word.pinyin)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)

            TextField("English translation", text: $word.translation)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(14)
        .background(TingXiePalette.lightGreenSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(TingXiePalette.outlineVariant.opacity(0.6), lineWidth: 1)
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
// Seeds previews with representative practice data without touching the user's store.
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
