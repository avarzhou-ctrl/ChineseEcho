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
                initialTitle: initialTitle,
                initialWords: initialWords
            ) { title, words in
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.updateSet(
                    setID: setID,
                    title: title,
                    words: words
                )
            }
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
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(TingXiePalette.onBackground)
                        .lineLimit(1)

                    if let matchingWord {
                        Text("Match: \(matchingWord.chinese)  ·  \(matchingWord.pinyin)")
                            .lineLimit(1)
                    } else {
                        Text("\(set.vocabularyWords.count) vocabulary words")
                    }
                }
                .font(.system(size: 12, design: .rounded))
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
                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(maxWidth: 480, alignment: .leading)

                Text("Build a custom set from the Chinese you are learning, then listen, flip, and review at your own pace.")
                    .font(.system(size: 15, design: .rounded))
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
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, minHeight: 180)
                .tonalCard()
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

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
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
                }
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, minHeight: 78)
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
                    .frame(width: 60, height: 56)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.trailing, 20)
            .help("Edit \(set.title)")
            .accessibilityLabel("Edit \(set.title)")

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.45))
                .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .tonalCard()
    }
}

// Defines whether a practice session includes every word or only missed words.
private enum PracticeFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }
}

// Coordinates filtered practice progress, speech repetition, and missed-word updates.
private struct PracticeSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let set: DictationSet
    let onFinish: () -> Void

    @AppStorage(AppPreferenceKey.repeatCount)
    private var repeatCount = AppPreferenceDefault.repeatCount
    @AppStorage(AppPreferenceKey.automaticProgression)
    private var automaticProgression = AppPreferenceDefault.automaticProgression
    @AppStorage(AppPreferenceKey.keepCardsRevealed)
    private var keepCardsRevealed = AppPreferenceDefault.keepCardsRevealed

    @State private var filter: PracticeFilter = .all
    @State private var currentIndex = 0
    @State private var isCardFlipped = false
    @State private var currentRepetition = 1
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
            WorkspaceHeader(
                title: "Practice Session",
                info: WorkspaceInfo(
                    title: "About Practice Sessions",
                    symbol: "rectangle.on.rectangle.angled",
                    summary: "Listen first, then flip each card to check the characters before deciding whether the word needs more review.",
                    tips: [
                        "Select the card or press Return or Space to flip between the listening prompt and the answer.",
                        "Mark Missed becomes available after the answer is visible.",
                        "Playback repeats and automatic progression follow your choices in Settings."
                    ]
                )
            )

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
            audioEngine.configureFromPreferences()
            isCardFlipped = keepCardsRevealed
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
            currentRepetition = 1
            isCardFlipped = keepCardsRevealed
            restartContinuousPlaybackIfNeeded()
        }
        .onChange(of: currentIndex) { _, _ in
            currentRepetition = 1
            isCardFlipped = keepCardsRevealed
        }
        .onChange(of: keepCardsRevealed) { _, shouldReveal in
            isCardFlipped = shouldReveal
        }
    }

    private var practiceContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            if let currentWord {
                PracticeFlipCard(
                    word: currentWord,
                    isFlipped: $isCardFlipped,
                    reduceMotion: reduceMotion
                )
                    .frame(maxWidth: 650, minHeight: 300, maxHeight: 360)

                HStack(spacing: 30) {
                    PracticeRoundButton(
                        title: isContinuousPlaybackActive ? "STOP AUDIO" : "PLAY AUDIO",
                        symbol: isContinuousPlaybackActive ? "stop.fill" : "play.fill",
                        color: TingXiePalette.accent,
                        action: toggleContinuousPlayback
                    )
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .frame(minWidth: 170)

                    PracticeRoundButton(
                        title: "MARK MISSED",
                        symbol: "flag",
                        color: TingXiePalette.missed,
                        isDisabled: !isCardFlipped,
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
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Finish Set", systemImage: "rectangle.portrait.and.arrow.right", action: onFinish)
                    .buttonStyle(OutlineCapsuleButtonStyle())
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
            currentRepetition = 1
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
        if currentRepetition < max(repeatCount, 1) {
            currentRepetition += 1
            speakCurrentWord()
        } else if automaticProgression, currentIndex < words.count - 1 {
            currentIndex += 1
            currentRepetition = 1
            audioEngine.speak(words[currentIndex].chinese)
        } else {
            isContinuousPlaybackActive = false
            currentRepetition = 1
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

// Presents the full-set and missed-only practice modes as a compact segmented control.
private struct PracticeFilterBar: View {
    @Binding var selection: PracticeFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PracticeFilter.allCases) { item in
                Button {
                    selection = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == item ? TingXiePalette.accent : TingXiePalette.onSurfaceVariant)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selection == item ? Color.white : .clear, in: Capsule())
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(TingXiePalette.surfaceContainerHigh, in: Capsule())
    }
}

// Flips between an audio-first prompt and the complete vocabulary answer.
private struct PracticeFlipCard: View {
    let word: VocabularyWord
    @Binding var isFlipped: Bool
    let reduceMotion: Bool

    var body: some View {
        Button(action: flip) {
            ZStack {
                cardFace(isAnswer: false)
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))

                cardFace(isAnswer: true)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 28))
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
            Image(systemName: isAnswer ? "checkmark.circle.fill" : "speaker.wave.2.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(
                    isAnswer && word.isMissedWord
                        ? TingXiePalette.missed
                        : TingXiePalette.secondary.opacity(isAnswer ? 0.8 : 0.5)
                )

            if isAnswer {
                Text(word.chinese)
                    .font(.system(size: word.chinese.count > 4 ? 48 : 64, weight: .bold, design: .rounded))
                    .foregroundStyle(word.isMissedWord ? TingXiePalette.missed : TingXiePalette.accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)

                Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.78))
            } else {
                Text(word.pinyin.isEmpty ? "Listen carefully" : word.pinyin)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)

                HStack(spacing: 12) {
                    ForEach(Array(word.chinese.enumerated()), id: \.offset) { _, _ in
                        Text("?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(TingXiePalette.secondary.opacity(0.18))
                            .frame(width: 64, height: 72)
                            .background(TingXiePalette.surfaceContainerHigh.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        TingXiePalette.secondary.opacity(0.18),
                                        style: StrokeStyle(lineWidth: 1, dash: [5])
                                    )
                            }
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .background(TingXiePalette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.8), lineWidth: 1) }
        .shadow(color: TingXiePalette.accent.opacity(0.11), radius: 28, y: 16)
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

// Standardizes circular actions shown beneath the practice card.
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
struct NewDictationSetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: DictationSetEditorMode
    let onSave: (String, [NewVocabularyWord]) async throws -> Void

    @State private var title: String
    @State private var chineseWordInput = ""
    @State private var manualText = ""
    @State private var draftWords: [DraftVocabularyWord]
    @State private var errorMessage: String?
    @State private var initialModelOutput = ""
    @State private var repairModelOutput = ""
    @State private var isSaving = false
    @State private var isGenerating = false

    init(
        mode: DictationSetEditorMode = .create,
        initialTitle: String = "",
        initialWords: [NewVocabularyWord] = [],
        onSave: @escaping (String, [NewVocabularyWord]) async throws -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _draftWords = State(initialValue: initialWords.map { DraftVocabularyWord($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "character.book.closed")
                    .foregroundStyle(TingXiePalette.accent)
                Text(mode.title)
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

            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text("Set Name")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                if let errorMessage {
                                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(TingXiePalette.missed)
                                        .lineLimit(1)
                                        .help(errorMessage)
                                }
                            }
                            TextField("e.g., Travel essentials", text: $title)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 9))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Fill Vocabulary Details", systemImage: "text.book.closed")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(TingXiePalette.accent)

                            Text("Enter Chinese words separated by commas, spaces, or new lines. TingXieFlow looks them up in its offline CC-CEDICT dictionary, then uses Local AI only for unmatched words.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                .lineSpacing(2)

                            TextEditor(text: $chineseWordInput)
                                .font(.system(size: 13, design: .rounded))
                                .scrollContentBackground(.hidden)
                                .padding(9)
                                .frame(minHeight: 110)
                                .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityLabel("Chinese words to enrich")

                            HStack {
                                Text("Example: 苹果, 学习  坚持")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                Spacer()
                                Button(action: enrichChineseWords) {
                                    if isGenerating {
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
                                .disabled(inputChineseWords.isEmpty || isGenerating)
                            }
                        }
                        .padding(16)
                        .background(TingXiePalette.surfaceContainer.opacity(0.62), in: RoundedRectangle(cornerRadius: 14))

                        modelOutputPanel

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manual Import")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            TextEditor(text: $manualText)
                                .font(.system(size: 12, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 90)
                                .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 9))
                            HStack {
                                Text("One per line: Chinese | pinyin | translation")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                                Spacer()
                                Button("Import Lines", systemImage: "square.and.arrow.down", action: importManualLines)
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("\(validWords.count) ready to save")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        }
                        Spacer()
                        Button("Add Word", systemImage: "plus", action: addBlankWord)
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 10, design: .rounded))
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
        .background(TingXiePalette.surface.opacity(0.84))
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
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(TingXiePalette.accent)
                    Spacer()
                    Button("Copy", systemImage: "doc.on.doc", action: copyModelOutput)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                .font(.system(size: 10, weight: .bold, design: .rounded))
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
            .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 8))
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

    private func save() {
        if let saveValidationMessage {
            errorMessage = saveValidationMessage
            return
        }

        let words = validWords
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
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 90)

                Toggle("Idiom", isOn: $word.isIdiom)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10, design: .rounded))

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
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)

            TextField("English translation", text: $word.translation)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .rounded))
        }
        .padding(14)
        .background(TingXiePalette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
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
