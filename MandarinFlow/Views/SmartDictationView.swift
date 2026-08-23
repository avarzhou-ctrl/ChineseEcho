import AppKit
import AVFoundation
import SwiftData
import SwiftUI

// Drives dictation-set search, list actions, practice presentation, and editor sheets.
struct SmartDictationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sets: [DictationSet]
    let activeSet: DictationSet?
    let isDueReviewActive: Bool
    let onCreateSet: () -> Void
    let onOpenVocabulary: () -> Void
    let onOpenSet: (DictationSet) -> Void
    let onOpenDueReview: () -> Void
    let onCloseSet: () -> Void

    @State private var searchText = ""
    @State private var isSearchResultsPresented = false
    @State private var highlightedSearchSetID: PersistentIdentifier?
    @State private var editingSet: DictationSet?
    @State private var setPendingDeletion: DictationSet?
    @State private var operationError: String?

    private var allWords: [VocabularyWord] {
        sets.flatMap(\.vocabularyWords)
    }

    private var dueWords: [VocabularyWord] {
        allWords
            .filter { ReviewScheduler.isDue($0.nextReviewAt) }
            .sorted {
                ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture)
            }
    }

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
            if isDueReviewActive {
                PracticeSessionView(
                    source: .dueReview(
                        words: allWords,
                        initialWordRecordIDs: dueWords.map(\.recordID)
                    ),
                    onClose: onCloseSet,
                    onFinish: onCloseSet
                )
                .transition(
                    TingXieMotion.directionalTransition(
                        enteringFrom: .trailing,
                        reduceMotion: reduceMotion
                    )
                )
            } else if let activeSet {
                PracticeSessionView(
                    source: .set(activeSet),
                    onClose: onCloseSet,
                    onFinish: onCloseSet
                )
                .transition(
                    TingXieMotion.directionalTransition(
                        enteringFrom: .trailing,
                        reduceMotion: reduceMotion
                    )
                )
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

                                DueReviewCard(
                                    words: allWords,
                                    dueWords: dueWords,
                                    onStartReview: onOpenDueReview
                                )

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
                    }
                    .buttonStyle(TingXieButtonStyle(size: .prominent, isIconOnly: true))
                    .help("Create New Set")
                    .accessibilityLabel("Create New Set")
                    .padding(.trailing, 32)
                    .padding(.bottom, 30)
                }
                .transition(
                    TingXieMotion.directionalTransition(
                        enteringFrom: .leading,
                        reduceMotion: reduceMotion
                    )
                )
            }
        }
        .clipped()
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onChange(of: searchText) { _, _ in
            highlightedSearchSetID = filteredSets.first?.persistentModelID
            isSearchResultsPresented = !searchText.tingXieTrimmed.isEmpty
        }
        .sheet(item: $editingSet) { set in
            let setID = set.persistentModelID
            let initialTitle = set.title
            let initialAppearance = set.appearance
            let initialWords = set.vocabularyWords.map { NewVocabularyWord($0) }

            NewDictationSetSheet(
                mode: .edit,
                modelContainer: modelContext.container,
                setID: setID,
                initialTitle: initialTitle,
                initialAppearance: initialAppearance,
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
                DictationSetIconBadge(
                    appearance: set.appearance,
                    size: 32,
                    cornerRadius: TingXieControlMetrics.compactCornerRadius
                )

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
                    .buttonStyle(TingXieButtonStyle(variant: .secondary))
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
                colors: [
                    TingXiePalette.lightGreenSurface.opacity(0.96),
                    TingXiePalette.surfaceContainer.opacity(0.78)
                ],
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

// Surfaces scheduled work without displacing Word of the Day or normal set practice.
private struct DueReviewCard: View {
    let words: [VocabularyWord]
    let dueWords: [VocabularyWord]
    let onStartReview: () -> Void

    private var nextReviewAt: Date? {
        words.compactMap(\.nextReviewAt).filter { $0 > Date() }.min()
    }

    private var detailText: Text {
        if !dueWords.isEmpty {
            let countText = dueWords.count == 1 ? "1 word" : "\(dueWords.count) words"
            let remainder = dueWords.count == 1
                ? " is ready for a quick review."
                : " are ready for a quick review."
            return Text(countText).bold() + Text(remainder)
        }
        if let nextReviewAt {
            let relativeTime = nextReviewAt.formatted(.relative(presentation: .named))
            if relativeTime.hasPrefix("in ") {
                let duration = String(relativeTime.dropFirst(3))
                return Text("You’re caught up. Next review in ") + Text(duration).bold() + Text(".")
            }
            return Text("You’re caught up. Next review ") + Text(relativeTime).bold() + Text(".")
        }
        return Text("Complete a dictation card to begin scheduling reviews.")
    }

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: dueWords.isEmpty ? "checkmark.circle.fill" : "calendar.badge.clock")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(dueWords.isEmpty ? TingXiePalette.secondary : .white)
                .frame(width: 48, height: 48)
                .background(
                    dueWords.isEmpty
                        ? TingXiePalette.surfaceContainerHigh
                        : TingXiePalette.accent,
                    in: RoundedRectangle(cornerRadius: 13)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Text("Due Review")
                        .font(TingXieTypography.sectionTitle)

                    if !dueWords.isEmpty {
                        Text("\(dueWords.count) due now")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TingXiePalette.accent)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(TingXiePalette.accent.opacity(0.1), in: Capsule())
                    }
                }
                detailText
                    .font(.system(size: 13))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }

            Spacer()

            if !dueWords.isEmpty {
                Button("Start Review", systemImage: "play.fill", action: onStartReview)
                    .buttonStyle(TingXieButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: dueWords.isEmpty ? 76 : 100)
        .background(
            dueWords.isEmpty
                ? TingXiePalette.lightGreenSurface.opacity(0.58)
                : TingXiePalette.surfaceContainerHigh.opacity(0.92),
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.prominentCardCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TingXieControlMetrics.prominentCardCornerRadius)
                .stroke(
                    dueWords.isEmpty ? .white.opacity(0.58) : TingXiePalette.accent.opacity(0.48),
                    lineWidth: dueWords.isEmpty ? 1 : 1.5
                )
        }
        .shadow(
            color: dueWords.isEmpty ? .clear : TingXiePalette.accent.opacity(0.12),
            radius: 10,
            y: 4
        )
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
                            .buttonStyle(TingXieButtonStyle())
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

    private var setKey: String {
        PracticeAnalyticsStore.setKey(for: set.dateCreated)
    }

    private var progress: Double {
        guard !vocabularyKeys.isEmpty else { return 0 }
        let masteredCount = analytics
            .masteredVocabulary(forSetKey: setKey)
            .intersection(vocabularyKeys)
            .count
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
                    DictationSetIconBadge(appearance: set.appearance)

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

// Lets one immersive practice flow serve a set or a scheduled cross-set queue.
private enum PracticeSessionSource {
    case set(DictationSet)
    case dueReview(words: [VocabularyWord], initialWordRecordIDs: [UUID])

    var words: [VocabularyWord] {
        switch self {
        case .set(let set): set.vocabularyWords
        case .dueReview(let words, _): words
        }
    }

    var title: String {
        switch self {
        case .set(let set): set.title
        case .dueReview: "Due Review"
        }
    }

    var appearance: DictationSetAppearance? {
        guard case .set(let set) = self else { return nil }
        return set.appearance
    }

    var setRecordID: UUID? {
        guard case .set(let set) = self else { return nil }
        return set.recordID
    }

    var savedKind: SavedPracticeSourceKind {
        switch self {
        case .set: .set
        case .dueReview: .dueReview
        }
    }

    var supportsFilters: Bool {
        if case .set = self { return true }
        return false
    }

    var initialDueWordRecordIDs: [UUID] {
        guard case .dueReview(_, let wordIDs) = self else { return [] }
        return wordIDs
    }
}

// Captures the persisted word state needed to reverse one grading decision.
private struct PracticeGradeAction {
    let wordID: PersistentIdentifier
    let queueIndex: Int
    let wasMissed: Bool
    let markedMissed: Bool
    let vocabularyKey: String
    let recordedAt: Date
    let previousMastery: Bool?
    let previousSetMastery: Bool?
    let previousReviewSchedule: ReviewScheduleSnapshot
    let setKey: String
}

// Freezes the current session results so the summary stays stable while it is visible.
private struct PracticeSessionSummaryData {
    struct Word: Identifiable {
        let id: PersistentIdentifier
        let chinese: String
        let pinyin: String
    }

    let gradedWordCount: Int
    let availableWordCount: Int
    let learnedWords: [Word]
    let missedWords: [Word]

    var accuracy: Double? {
        guard gradedWordCount > 0 else { return nil }
        return Double(learnedWords.count) / Double(gradedWordCount)
    }

    var isComplete: Bool {
        gradedWordCount >= availableWordCount
    }
}

// Coordinates filtered practice progress, speech repetition, and missed-word updates.
private struct PracticeSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let source: PracticeSessionSource
    let onClose: () -> Void
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
    @State private var revealedHintWordIDs: Set<PersistentIdentifier> = []
    @State private var summary: PracticeSessionSummaryData?
    @State private var queuedFollowUpWordIDs: [PersistentIdentifier]?
    @State private var audioEngine = SpeechAudioEngine()
    @State private var isConfirmingStartOver = false
    @State private var suppressNextFilterReset = false
    @State private var shouldDiscardOnDisappear = false
    @State private var dueQueueRecordIDs: [UUID]

    init(
        source: PracticeSessionSource,
        onClose: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.source = source
        self.onClose = onClose
        self.onFinish = onFinish
        _dueQueueRecordIDs = State(initialValue: source.initialDueWordRecordIDs)
    }

    private var filteredWords: [VocabularyWord] {
        if !source.supportsFilters {
            let recordIDs = Set(dueQueueRecordIDs)
            return source.words.filter { recordIDs.contains($0.recordID) }
        }
        return switch filter {
        case .all: source.words
        case .missed: source.words.filter(isMissed)
        case .idioms: source.words.filter(\.isIdiom)
        }
    }

    private var currentWord: VocabularyWord? {
        guard sessionWordIDs.indices.contains(currentIndex) else { return nil }
        let wordID = sessionWordIDs[currentIndex]
        return source.words.first { $0.persistentModelID == wordID }
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
            PracticeImmersiveHeader(
                title: summary == nil ? nil : "Session Summary",
                info: WorkspaceInfo(
                    title: "About Practice Sessions",
                    symbol: "rectangle.on.rectangle.angled",
                    summary: "Listen first, then flip each card to check the characters before deciding whether the word needs more review.",
                    tips: [
                        "Select the card or press Return or Space to flip between the listening prompt and the answer.",
                        "Request an optional learner hint without revealing the answer.",
                        "The missed and known actions appear only after the answer is visible.",
                        "Each card plays automatically using the repeat count in Settings; use the speaker for one extra playback."
                    ]
                ),
                onClose: closeSession
            )

            if let summary {
                PracticeSessionSummaryView(
                    sessionTitle: source.title,
                    isDueReview: !source.supportsFilters,
                    summary: summary,
                    onPracticeMissedWords: { startMissedWordsFollowUp(from: summary) },
                    onContinueSession: { self.summary = nil },
                    onFinish: finishSession
                )
            } else {
                HStack(alignment: .bottom, spacing: 20) {
                    HStack(spacing: 12) {
                        if let appearance = source.appearance {
                            DictationSetIconBadge(
                                appearance: appearance,
                                size: 40,
                                cornerRadius: 11
                            )
                        } else {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(TingXiePalette.accent)
                                .frame(width: 40, height: 40)
                                .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 11))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.supportsFilters ? "Current Set" : "Scheduled Practice")
                                .font(TingXieTypography.eyebrow)
                                .tracking(0.15)
                                .foregroundStyle(TingXiePalette.secondary)
                            Text(source.title)
                                .font(.system(size: 24, weight: .medium))
                        }
                    }
                    Spacer()
                    if source.supportsFilters {
                        PracticeFilterBar(selection: animatedFilter)
                            .frame(maxWidth: 430)
                    }
                }
                .padding(.horizontal, 40)

                Group {
                    if !hasInitializedQueue {
                        PracticeCardSkeleton()
                    } else if sessionWordIDs.isEmpty {
                        ContentUnavailableView(
                            source.supportsFilters ? "No Words in This Filter" : "No Reviews Due",
                            systemImage: source.supportsFilters ? "text.magnifyingglass" : "checkmark.circle",
                            description: Text(
                                source.supportsFilters
                                    ? "Choose a different category to continue practicing."
                                    : "Complete normal dictation practice to schedule future reviews."
                            )
                        )
                    } else {
                        practiceContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onAppear {
            audioEngine.configureFromPreferences()
            audioEngine.onUtteranceFinished = {
                Task { @MainActor in continueAutomaticPlayback() }
            }
            restoreSessionOrStartNew()
        }
        .onDisappear {
            stopPlayback()
            audioEngine.onUtteranceFinished = nil
            if !shouldDiscardOnDisappear {
                persistSession()
            }
        }
        .onChange(of: filter) { _, _ in
            if suppressNextFilterReset {
                suppressNextFilterReset = false
                return
            }
            if let queuedFollowUpWordIDs {
                self.queuedFollowUpWordIDs = nil
                resetSessionQueue(wordIDs: queuedFollowUpWordIDs)
            } else {
                resetSessionQueue()
            }
        }
        .onChange(of: keepCardsRevealed) { _, shouldReveal in
            isCardFlipped = shouldReveal
        }
        .onChange(of: isCardFlipped) { _, _ in persistSession() }
        .confirmationDialog(
            "Start This Practice Over?",
            isPresented: $isConfirmingStartOver,
            titleVisibility: .visible
        ) {
            Button("Start Over", role: .destructive, action: startSessionOver)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This discards the saved queue and completed grading for this session. Your overall learning progress and missed-word status stay recorded.")
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
                .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact))
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
                        isHintRevealed: revealedHintWordIDs.contains(currentWord.persistentModelID),
                        onRevealHint: {
                            revealedHintWordIDs.insert(currentWord.persistentModelID)
                        },
                        reduceMotion: reduceMotion
                    )

                    Button(action: replayCurrentWord) {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .buttonStyle(
                        TingXieButtonStyle(
                            variant: .secondary,
                            isIconOnly: true
                        )
                    )
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
                    Text("\(gradeHistory.count) of \(sessionWordIDs.count) cards")
                        .font(.system(size: 13, weight: .semibold))
                    ProgressView(
                        value: Double(gradeHistory.count),
                        total: Double(max(sessionWordIDs.count, 1))
                    )
                        .tint(TingXiePalette.accent)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Start Over", systemImage: "arrow.counterclockwise") {
                        isConfirmingStartOver = true
                    }
                    .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))
                    .help("Discard saved progress and restart this practice mode")

                    Button(
                        source.supportsFilters ? "Finish Set" : "Finish Review",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        action: presentSummary
                    )
                        .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))
                }
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

    private func resetSessionQueue(wordIDs: [PersistentIdentifier]? = nil) {
        stopPlayback()
        sessionWordIDs = wordIDs ?? filteredWords.map(\.persistentModelID)
        currentIndex = 0
        gradeHistory.removeAll()
        revealedHintWordIDs.removeAll()
        summary = nil
        hasGradedCurrentCard = false
        hasInitializedQueue = true
        isQueueShuffled = false
        isCardFlipped = keepCardsRevealed
        persistSession()
        scheduleAutomaticPlayback()
    }

    private func restoreSessionOrStartNew() {
        guard let saved = PracticeSessionStore.load(),
              saved.resolvedSourceKind == source.savedKind,
              saved.resolvedSourceKind == .dueReview || saved.setRecordID == source.setRecordID
        else {
            resetSessionQueue()
            return
        }

        let restoredFilter = PracticeFilter(rawValue: saved.filter) ?? .all

        let wordsByRecordID = Dictionary(uniqueKeysWithValues: source.words.map {
            ($0.recordID, $0)
        })
        let restoredWords = saved.queueWordRecordIDs.compactMap { wordsByRecordID[$0] }
        let restoredGrades = saved.grades.compactMap { savedGrade -> PracticeGradeAction? in
            guard let word = wordsByRecordID[savedGrade.wordRecordID] else { return nil }
            return PracticeGradeAction(
                wordID: word.persistentModelID,
                queueIndex: savedGrade.queueIndex,
                wasMissed: savedGrade.wasMissed,
                markedMissed: savedGrade.markedMissed,
                vocabularyKey: savedGrade.vocabularyKey,
                recordedAt: savedGrade.recordedAt,
                previousMastery: savedGrade.previousMastery,
                previousSetMastery: savedGrade.previousSetMastery,
                previousReviewSchedule: savedGrade.previousReviewSchedule ?? .unscheduled,
                setKey: setKey(for: word)
            )
        }
        guard !restoredWords.isEmpty,
              restoredWords.count == saved.queueWordRecordIDs.count,
              restoredGrades.count == saved.grades.count,
              saved.currentIndex >= 0,
              saved.currentIndex < restoredWords.count
        else {
            PracticeSessionStore.clear()
            resetSessionQueue()
            return
        }

        stopPlayback()
        if filter != restoredFilter {
            suppressNextFilterReset = true
            filter = restoredFilter
        }
        sessionWordIDs = restoredWords.map(\.persistentModelID)
        if !source.supportsFilters {
            dueQueueRecordIDs = saved.queueWordRecordIDs
        }
        currentIndex = saved.currentIndex
        gradeHistory = restoredGrades
        missedOverrides = Dictionary(uniqueKeysWithValues: restoredGrades.map {
            ($0.wordID, $0.markedMissed)
        })
        revealedHintWordIDs.removeAll()
        isQueueShuffled = saved.isQueueShuffled
        isCardFlipped = saved.isCardFlipped
        hasGradedCurrentCard = restoredGrades.last?.queueIndex == saved.currentIndex
        hasInitializedQueue = true
        shouldDiscardOnDisappear = false

        if restoredGrades.count >= restoredWords.count {
            presentSummary()
        } else {
            scheduleAutomaticPlayback()
        }
    }

    private func persistSession() {
        guard hasInitializedQueue, !sessionWordIDs.isEmpty, !shouldDiscardOnDisappear else { return }
        let wordsByID = Dictionary(uniqueKeysWithValues: source.words.map {
            ($0.persistentModelID, $0)
        })
        let queueRecordIDs = sessionWordIDs.compactMap { wordsByID[$0]?.recordID }
        guard queueRecordIDs.count == sessionWordIDs.count else { return }
        let savedGrades = gradeHistory.compactMap { action -> SavedPracticeGrade? in
            guard let recordID = wordsByID[action.wordID]?.recordID else { return nil }
            return SavedPracticeGrade(
                wordRecordID: recordID,
                queueIndex: action.queueIndex,
                wasMissed: action.wasMissed,
                markedMissed: action.markedMissed,
                vocabularyKey: action.vocabularyKey,
                recordedAt: action.recordedAt,
                previousMastery: action.previousMastery,
                previousSetMastery: action.previousSetMastery,
                previousReviewSchedule: action.previousReviewSchedule
            )
        }
        guard savedGrades.count == gradeHistory.count else { return }
        PracticeSessionStore.save(
            SavedPracticeSession(
                version: SavedPracticeSession.currentVersion,
                sourceKind: source.savedKind,
                setRecordID: source.setRecordID,
                filter: filter.rawValue,
                queueWordRecordIDs: queueRecordIDs,
                currentIndex: currentIndex,
                grades: savedGrades,
                isQueueShuffled: isQueueShuffled,
                isCardFlipped: isCardFlipped,
                savedAt: Date()
            )
        )
    }

    private func startSessionOver() {
        PracticeSessionStore.clear()
        shouldDiscardOnDisappear = false
        resetSessionQueue()
    }

    private func closeSession() {
        persistSession()
        onClose()
    }

    private func finishSession() {
        shouldDiscardOnDisappear = true
        PracticeSessionStore.clear()
        onFinish()
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
        persistSession()
        scheduleAutomaticPlayback()
    }

    private func gradeCurrentWord(asMissed: Bool) {
        guard canGradeCurrentCard, let currentWord else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        let wordID = currentWord.persistentModelID
        let wordRecordID = currentWord.recordID
        let vocabularyKey = currentWord.chinese.tingXieTrimmed
        let currentSetKey = setKey(for: currentWord)
        let gradedQueueIndex = currentIndex
        let recordedAt = Date()
        let previousMastery = PracticeAnalyticsStore.masteryState(for: vocabularyKey)
        let previousSetMastery = PracticeAnalyticsStore.masteryState(
            for: vocabularyKey,
            setKey: currentSetKey
        )
        isUpdatingGrade = true
        stopPlayback()

        Task {
            do {
                let previousState = try await store.applyPracticeResult(
                    PracticeResultRequest(
                        wordRecordID: wordRecordID,
                        isMissed: asMissed,
                        reviewedAt: recordedAt
                    )
                )
                let action = PracticeGradeAction(
                    wordID: wordID,
                    queueIndex: gradedQueueIndex,
                    wasMissed: previousState.wasMissed,
                    markedMissed: asMissed,
                    vocabularyKey: vocabularyKey,
                    recordedAt: recordedAt,
                    previousMastery: previousMastery,
                    previousSetMastery: previousSetMastery,
                    previousReviewSchedule: previousState.schedule,
                    setKey: currentSetKey
                )
                missedOverrides[wordID] = asMissed
                PracticeAnalyticsStore.recordResult(
                    isCorrect: !asMissed,
                    vocabularyKey: action.vocabularyKey,
                    setKey: currentSetKey
                )
                gradeHistory.append(action)
                hasGradedCurrentCard = true

                if currentIndex < sessionWordIDs.count - 1 {
                    cardTransitionEdge = .trailing
                    currentIndex += 1
                    hasGradedCurrentCard = false
                    isCardFlipped = keepCardsRevealed
                    persistSession()
                    scheduleAutomaticPlayback()
                } else {
                    persistSession()
                    presentSummary()
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
                guard let word = source.words.first(where: {
                    $0.persistentModelID == action.wordID
                }) else { return }
                try await store.restorePracticeResult(
                    PracticeResultRestoreRequest(
                        wordRecordID: word.recordID,
                        wasMissed: action.wasMissed,
                        schedule: action.previousReviewSchedule
                    )
                )
                missedOverrides[action.wordID] = action.wasMissed
                PracticeAnalyticsStore.undoResult(
                    isCorrect: !action.markedMissed,
                    vocabularyKey: action.vocabularyKey,
                    setKey: action.setKey,
                    recordedAt: action.recordedAt,
                    restoringMastery: action.previousMastery,
                    restoringSetMastery: action.previousSetMastery
                )
                gradeHistory.removeLast()
                cardTransitionEdge = .leading
                currentIndex = min(action.queueIndex, max(sessionWordIDs.count - 1, 0))
                hasGradedCurrentCard = false
                isCardFlipped = false
                persistSession()
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

    private func presentSummary() {
        stopPlayback()
        let resultWords = gradeHistory.compactMap { action -> (PracticeGradeAction, VocabularyWord)? in
            guard let word = source.words.first(where: {
                $0.persistentModelID == action.wordID
            }) else { return nil }
            return (action, word)
        }
        let learnedWords = resultWords.compactMap { action, word -> PracticeSessionSummaryData.Word? in
            guard !action.markedMissed else { return nil }
            return .init(id: action.wordID, chinese: word.chinese, pinyin: word.pinyin)
        }
        let missedWords = resultWords.compactMap { action, word -> PracticeSessionSummaryData.Word? in
            guard action.markedMissed else { return nil }
            return .init(id: action.wordID, chinese: word.chinese, pinyin: word.pinyin)
        }
        summary = PracticeSessionSummaryData(
            gradedWordCount: resultWords.count,
            availableWordCount: sessionWordIDs.count,
            learnedWords: learnedWords,
            missedWords: missedWords
        )
    }

    private func startMissedWordsFollowUp(from summary: PracticeSessionSummaryData) {
        let wordIDs = summary.missedWords.map(\.id)
        guard !wordIDs.isEmpty else { return }
        queuedFollowUpWordIDs = wordIDs
        self.summary = nil
        if !source.supportsFilters || filter == .missed {
            queuedFollowUpWordIDs = nil
            resetSessionQueue(wordIDs: wordIDs)
        } else {
            filterTransitionEdge = .trailing
            cardTransitionEdge = .trailing
            filter = .missed
        }
    }

    private func setKey(for word: VocabularyWord) -> String {
        guard let set = word.session else { return "word-\(word.recordID.uuidString)" }
        return PracticeAnalyticsStore.setKey(for: set.dateCreated)
    }
}

// Provides minimal navigation chrome while practice occupies the full workspace.
private struct PracticeImmersiveHeader: View {
    let title: String?
    let info: WorkspaceInfo
    let onClose: () -> Void

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(TingXieTypography.sectionTitle)
                    .foregroundStyle(TingXiePalette.accent)
            }

            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(
                    TingXieButtonStyle(
                        variant: .quiet,
                        isIconOnly: true
                    )
                )
                .help("Return to dictation sets")
                .accessibilityLabel("Return to dictation sets")

                Spacer()

                WorkspaceInfoButton(
                    info: info,
                    accessibilityLabel: "About Practice Sessions"
                )
            }
        }
        .frame(height: 58)
        .padding(.horizontal, 24)
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

// Turns one completed or partial grading run into an actionable learning recap.
private struct PracticeSessionSummaryView: View {
    let sessionTitle: String
    let isDueReview: Bool
    let summary: PracticeSessionSummaryData
    let onPracticeMissedWords: () -> Void
    let onContinueSession: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: summary.isComplete ? "checkmark.seal.fill" : "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(TingXiePalette.accent)
                    Text(
                        summary.isComplete
                            ? (isDueReview ? "Review Complete" : "Set Complete")
                            : "Session So Far"
                    )
                        .font(.system(size: 28, weight: .semibold))
                    Text(sessionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    Text("\(summary.gradedWordCount) of \(summary.availableWordCount) words graded")
                        .font(.system(size: 12))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.78))
                }

                HStack(spacing: 14) {
                    SessionSummaryMetric(
                        title: "Accuracy",
                        value: accuracyText,
                        symbol: "scope",
                        color: TingXiePalette.accent
                    )
                    SessionSummaryMetric(
                        title: "Learned",
                        value: "\(summary.learnedWords.count)",
                        symbol: "checkmark.circle.fill",
                        color: TingXiePalette.secondary
                    )
                    SessionSummaryMetric(
                        title: "Missed",
                        value: "\(summary.missedWords.count)",
                        symbol: "xmark.circle.fill",
                        color: TingXiePalette.missed
                    )
                }

                HStack(alignment: .top, spacing: 14) {
                    SessionSummaryWordList(
                        title: "Learned Words",
                        words: summary.learnedWords,
                        color: TingXiePalette.secondary,
                        emptyMessage: "No words marked known yet."
                    )
                    SessionSummaryWordList(
                        title: "Missed Words",
                        words: summary.missedWords,
                        color: TingXiePalette.missed,
                        emptyMessage: "No missed words this session."
                    )
                }

                HStack(spacing: 14) {
                    if summary.isComplete {
                        Button("Return to Sets", systemImage: "rectangle.grid.1x2", action: onFinish)
                            .buttonStyle(TingXieButtonStyle(variant: .secondary))
                    } else {
                        Button("Continue Session", systemImage: "arrow.backward", action: onContinueSession)
                            .buttonStyle(TingXieButtonStyle(variant: .secondary))
                    }

                    Spacer()

                    if !summary.isComplete {
                        Button("Return to Sets", systemImage: "rectangle.grid.1x2", action: onFinish)
                            .buttonStyle(TingXieButtonStyle(variant: .quiet))
                    }

                    if !summary.missedWords.isEmpty {
                        Button("Practice Missed Words", systemImage: "arrow.clockwise", action: onPracticeMissedWords)
                            .buttonStyle(TingXieButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 40)
            .padding(.top, 4)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accuracyText: String {
        guard let accuracy = summary.accuracy else { return "—" }
        return accuracy.formatted(.percent.precision(.fractionLength(0)))
    }
}

// Displays one headline session value using the shared pale learning surface.
private struct SessionSummaryMetric: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TingXiePalette.onBackground)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TingXiePalette.lightGreenSurface,
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
                .strokeBorder(TingXiePalette.outlineVariant.opacity(0.65), lineWidth: 1)
        }
    }
}

// Lists the vocabulary behind a learned or missed session count.
private struct SessionSummaryWordList: View {
    let title: String
    let words: [PracticeSessionSummaryData.Word]
    let color: Color
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            if words.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            } else {
                ForEach(words) { word in
                    HStack(spacing: 10) {
                        Text(word.chinese)
                            .font(TingXieTypography.vocabulary(size: 20, weight: .bold))
                            .foregroundStyle(color)
                        Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            TingXiePalette.lightGreenSurface.opacity(0.72),
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
                .strokeBorder(TingXiePalette.outlineVariant.opacity(0.65), lineWidth: 1)
        }
    }
}

// Flips between an audio-first prompt and the complete vocabulary answer.
private struct PracticeFlipCard: View {
    let word: VocabularyWord
    let showsMissed: Bool
    @Binding var isFlipped: Bool
    let isHintRevealed: Bool
    let onRevealHint: () -> Void
    let reduceMotion: Bool

    var body: some View {
        ZStack {
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
            .accessibilityValue(revealedHintAccessibilityValue)
            .accessibilityHint("Flips the practice card")
            .overlay {
                Button("Flip Card", action: flip)
                    .keyboardShortcut(.space, modifiers: [])
                    .hidden()
                    .accessibilityHidden(true)
            }

            if !isFlipped, let hint = word.learnerHint?.tingXieNilIfEmpty {
                VStack {
                    Spacer()
                    if isHintRevealed {
                        Text("hint: \(hint)")
                            .font(.system(size: 11))
                            .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    } else {
                        Button("Show Hint", systemImage: "lightbulb", action: onRevealHint)
                            .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))
                            .help("Reveal the saved learner hint")
                    }
                }
                .padding(.bottom, 24)
                .padding(.horizontal, 28)
            }
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

    private var revealedHintAccessibilityValue: String {
        guard !isFlipped,
              isHintRevealed,
              let hint = word.learnerHint?.tingXieNilIfEmpty else { return "" }
        return "Hint: \(hint)"
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
    var learnerHint: String
    var isIdiom: Bool

    init(
        id: UUID = UUID(),
        chinese: String = "",
        pinyin: String = "",
        translation: String = "",
        learnerHint: String = "",
        isIdiom: Bool = false
    ) {
        self.id = id
        self.chinese = chinese
        self.pinyin = pinyin
        self.translation = translation
        self.learnerHint = learnerHint
        self.isIdiom = isIdiom
    }

    init(_ word: NewVocabularyWord) {
        self.init(
            chinese: word.chinese,
            pinyin: word.pinyin,
            translation: word.translation,
            learnerHint: word.learnerHint,
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
            learnerHint: learnerHint.trimmingCharacters(in: .whitespacesAndNewlines),
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
    @State private var appearance: DictationSetAppearance
    @State private var chineseWordInput = ""
    @State private var manualText = ""
    @State private var draftWords: [DraftVocabularyWord]
    @State private var errorMessage: String?
    @State private var initialModelOutput = ""
    @State private var repairModelOutput = ""
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var isAppearancePickerPresented = false
    @State private var modelDownloadCoordinator = ModelDownloadCoordinator.shared

    init(
        mode: DictationSetEditorMode = .create,
        modelContainer: ModelContainer,
        setID: PersistentIdentifier? = nil,
        initialTitle: String = "",
        initialAppearance: DictationSetAppearance = .defaultValue,
        initialWords: [NewVocabularyWord] = []
    ) {
        self.mode = mode
        self.modelContainer = modelContainer
        self.setID = setID
        _title = State(initialValue: initialTitle)
        _appearance = State(initialValue: initialAppearance)
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
                }
                .buttonStyle(
                    TingXieButtonStyle(
                        variant: .quiet,
                        isIconOnly: true
                    )
                )
                .accessibilityLabel("Close")
                .help("Close")
            }
            .tingXieSheetHeader()

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
                            HStack(spacing: 10) {
                                Button {
                                    isAppearancePickerPresented.toggle()
                                } label: {
                                    DictationSetIconBadge(
                                        appearance: appearance,
                                        size: 44,
                                        cornerRadius: TingXieControlMetrics.compactCornerRadius
                                    )
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "paintpalette.fill")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, height: 16)
                                            .background(TingXiePalette.accent, in: Circle())
                                            .offset(x: 3, y: 3)
                                    }
                                }
                                .buttonStyle(.plain)
                                .help("Customize set icon")
                                .accessibilityLabel("Customize set icon")
                                .popover(isPresented: $isAppearancePickerPresented, arrowEdge: .bottom) {
                                    DictationSetAppearancePicker(selection: $appearance)
                                }

                                TextField("e.g., Travel essentials", text: $title)
                                    .textFieldStyle(.plain)
                                    .tingXieInputSurface()
                            }
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
                                .padding(.vertical, 8)
                                .tingXieInputSurface(minimumHeight: 110)
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
                                .buttonStyle(TingXieButtonStyle(variant: .secondary, size: .compact))
                                .disabled(
                                    inputChineseWords.isEmpty
                                        || isGenerating
                                        || modelDownloadCoordinator.isPreparing
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            TingXiePalette.surfaceContainer.opacity(0.62),
                            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
                        )

                        modelOutputPanel

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manual Import")
                                .font(.system(size: 13, weight: .semibold))
                            TextEditor(text: $manualText)
                                .font(.system(size: 12, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(.vertical, 8)
                                .tingXieInputSurface(minimumHeight: 90)
                            HStack {
                                Text("One per line: Chinese | pinyin | translation")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                Spacer()
                                Button("Import Lines", systemImage: "square.and.arrow.down", action: importManualLines)
                                    .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact))
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
                            .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact))
                    }

                    Divider()

                    if isGenerating && draftWords.isEmpty {
                        ScrollView {
                            VocabularyDraftSkeleton()
                        }
                    } else if draftWords.isEmpty {
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
                    .buttonStyle(TingXieButtonStyle(variant: .quiet))
                Button(action: save) {
                    Label(isSaving ? "Saving…" : mode.actionTitle, systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(TingXieButtonStyle())
                .disabled(isSaving)
            }
            .tingXieSheetFooter()
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
                        .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact))
                }

                modelOutputSection(title: "Initial response", text: initialModelOutput)

                if !repairModelOutput.isEmpty {
                    Divider()
                    modelOutputSection(title: "Repair response", text: repairModelOutput)
                }
            }
            .padding(14)
            .background(
                TingXiePalette.surfaceContainer.opacity(0.62),
                in: RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
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
                                isIdiom: entry.isIdiom
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
                    isIdiom: false
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
            appearance: appearance,
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
                .buttonStyle(
                    TingXieButtonStyle(
                        variant: .quiet,
                        size: .compact,
                        isIconOnly: true
                    )
                )
                .disabled(!canMoveUp)
                .help("Move word up")
                .accessibilityLabel("Move word up")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(
                    TingXieButtonStyle(
                        variant: .quiet,
                        size: .compact,
                        isIconOnly: true
                    )
                )
                .disabled(!canMoveDown)
                .help("Move word down")
                .accessibilityLabel("Move word down")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(
                    TingXieButtonStyle(
                        variant: .destructive,
                        size: .compact,
                        isIconOnly: true
                    )
                )
                .help("Delete word")
                .accessibilityLabel("Delete word")
            }

            TextField("Pinyin", text: $word.pinyin)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)

            TextField("English translation", text: $word.translation)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            TextField("Optional learner hint", text: $word.learnerHint)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
        }
        .padding(14)
        .background(
            TingXiePalette.lightGreenSurface.opacity(0.78),
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
                .stroke(TingXiePalette.outlineVariant.opacity(0.6), lineWidth: 1)
        }
    }
}

#Preview("Smart Dictation — Empty") {
    SmartDictationView(
        sets: [], activeSet: nil, isDueReviewActive: false,
        onCreateSet: {}, onOpenVocabulary: {}, onOpenSet: { _ in },
        onOpenDueReview: {}, onCloseSet: {}
    )
    .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Smart Dictation — Sets") {
    let hskSet = DictationSet(title: "HSK 5 full set", dateCreated: Date.now.addingTimeInterval(-86_400))
    let idiomSet = DictationSet(title: "Everyday idioms", dateCreated: Date.now.addingTimeInterval(-172_800))
    SmartDictationView(
        sets: [hskSet, idiomSet], activeSet: nil, isDueReviewActive: false,
        onCreateSet: {}, onOpenVocabulary: {}, onOpenSet: { _ in },
        onOpenDueReview: {}, onCloseSet: {}
    )
    .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Smart Dictation — Due Review") {
    let set = DictationSet(title: "Everyday vocabulary")
    let word = VocabularyWord(
        chinese: "把握",
        englishTranslation: "to grasp",
        pinyin: "bǎ wò",
        reviewBox: 1,
        lastReviewedAt: Date.now.addingTimeInterval(-172_800),
        nextReviewAt: Date.now.addingTimeInterval(-86_400),
        tags: [set.title]
    )
    word.session = set
    set.vocabularyWords.append(word)
    return SmartDictationView(
        sets: [set], activeSet: nil, isDueReviewActive: false,
        onCreateSet: {}, onOpenVocabulary: {}, onOpenSet: { _ in },
        onOpenDueReview: {}, onCloseSet: {}
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
        sets: [set], activeSet: set, isDueReviewActive: false,
        onCreateSet: {}, onOpenVocabulary: {}, onOpenSet: { _ in },
        onOpenDueReview: {}, onCloseSet: {}
    )
    .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Smart Dictation — Practice") {
    smartDictationPracticePreview()
}
