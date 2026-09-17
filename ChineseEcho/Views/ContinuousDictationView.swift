import SwiftUI
import SwiftData

// Keeps uninterrupted listening separate from the draft answer sheet and recorded results.
struct ContinuousDictationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let title: String
    let words: [VocabularyWord]
    let initialSession: SavedPracticeSession
    let onClose: () -> Void
    let onFinish: () -> Void

    @State private var draft: SavedContinuousDictation
    @State private var queue: [UUID]
    @State private var index: Int
    @State private var audio = SpeechAudioEngine()
    @State private var countdownTask: Task<Void, Never>?
    @State private var remainingSeconds: Int?
    @State private var repetitionsLeft = 0
    @State private var isPaused = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isShuffled: Bool

    init(title: String, words: [VocabularyWord], initialSession: SavedPracticeSession,
         onClose: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.title = title
        self.words = words
        self.initialSession = initialSession
        self.onClose = onClose
        self.onFinish = onFinish
        _draft = State(initialValue: initialSession.dictation ?? SavedContinuousDictation())
        _queue = State(initialValue: initialSession.queueWordRecordIDs)
        _index = State(initialValue: initialSession.currentIndex)
        _isShuffled = State(initialValue: initialSession.isQueueShuffled)
    }

    private var currentWord: VocabularyWord? {
        guard queue.indices.contains(index) else { return nil }
        return words.first { $0.recordID == queue[index] }
    }
    private var attemptedWords: [VocabularyWord] {
        queue.filter { draft.heardWordIDs.contains($0) }.compactMap { id in
            words.first { $0.recordID == id }
        }
    }
    private var missedCount: Int { draft.missedWordIDs.count }
    private var correctCount: Int { attemptedWords.count - missedCount }
    private var hasHeardCurrent: Bool {
        queue.indices.contains(index) && draft.heardWordIDs.contains(queue[index])
    }

    var body: some View {
        VStack(spacing: draft.phase == .results ? 0 : 24) {
            if draft.phase == .results {
                PracticeImmersiveHeader(
                    title: "Session Summary",
                    info: WorkspaceInfo(
                        title: "About Dictation Results",
                        symbol: "checklist",
                        summary: "Review your saved dictation results and choose what to practice next.",
                        tips: [
                            "Learned and missed words reflect the answers you checked in this session.",
                            "Practice Missed Words starts a new dictation with only those words.",
                            "Continue Session plays the remaining words after an early finish."
                        ]
                    ),
                    onClose: onClose
                )
            } else {
                sessionHeader
            }

            switch draft.phase {
            case .listening: listeningView
            case .ready: readyView
            case .marking: markingView
            case .results: resultsView
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(TingXiePalette.missed)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .padding(draft.phase == .results ? 0 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .onAppear {
            audio.configureFromPreferences()
            audio.onUtteranceFinished = speechFinished
            audio.onPlaybackFailed = {
                pause()
                errorMessage = "Audio could not play. Choose Repeat to try again."
            }
            persist()
            // Resume checkpoints start paused so reopening never surprises the learner.
            if draft.phase == .listening && draft.heardWordIDs.isEmpty && index == 0 {
                playCurrentWord()
            }
        }
        .onDisappear {
            pause()
            audio.onUtteranceFinished = nil
            audio.onPlaybackFailed = nil
            persist()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pause(); persist() }
        }
    }

    private var sessionHeader: some View {
        HStack {
            Button {
                pause()
                persist()
                onClose()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(TingXieButtonStyle(variant: .quiet, isIconOnly: true))
            .accessibilityLabel("Return to sets and save progress")
            .disabled(isSaving)
            Spacer()
            Text(title).font(.headline).lineLimit(1)
            Spacer()
            Text("Dictation").font(.callout).foregroundStyle(TingXiePalette.onSurfaceVariant)
        }
    }

    private var listeningView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 22) {
                Image(systemName: isPaused ? "pause.circle" : "headphones")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(TingXiePalette.accent)
                Text("Word \(index + 1) of \(queue.count)")
                    .font(.system(size: 30, weight: .semibold))
                Text(isPaused ? "Paused" : remainingSeconds.map { "Time to write · \($0)s" } ?? "Listen carefully")
                    .font(.title3)
                    .monospacedDigit()
                Text("Write your answer on paper. You’ll check it at the end.")
                    .font(.callout)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            .frame(maxWidth: 650, minHeight: 280)
            .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 24))

            HStack(spacing: 16) {
                Button("Previous", systemImage: "arrow.left", action: previousWord)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .buttonStyle(TingXieButtonStyle(variant: .secondary))
                    .help("Replay the previous word (Left Arrow)")
                    .disabled(index == 0)
                Button(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                    if isPaused {
                        if remainingSeconds != nil { isPaused = false; startCountdown() }
                        else { playCurrentWord() }
                    } else { pause() }
                }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(TingXieButtonStyle(variant: .primary))
                Button("Repeat", systemImage: "speaker.wave.2.fill", action: playCurrentWord)
                    .keyboardShortcut("r", modifiers: [])
                    .buttonStyle(TingXieButtonStyle(variant: .secondary))
                Button("Next", systemImage: "arrow.right", action: advance)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .buttonStyle(TingXieButtonStyle(variant: .secondary))
                    .disabled(!hasHeardCurrent)
            }
            HStack {
                Text("Writing time")
                Stepper("\(draft.writingSeconds)s", value: $draft.writingSeconds, in: 3...30)
                    .fixedSize()
                    .onChange(of: draft.writingSeconds) { _, seconds in
                        UserDefaults.standard.set(seconds, forKey: AppPreferenceKey.dictationWritingSeconds)
                        if remainingSeconds != nil {
                            remainingSeconds = seconds
                            if !isPaused { startCountdown() }
                        }
                        persist()
                    }
            }
            .font(.callout)
            Spacer()
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(draft.heardWordIDs.count) of \(queue.count) words played")
                        .font(.callout)
                    ProgressView(value: Double(draft.heardWordIDs.count), total: Double(max(queue.count, 1)))
                        .progressViewStyle(DictationProgressBarStyle())
                        .accessibilityLabel("Words played")
                        .accessibilityValue("\(draft.heardWordIDs.count) of \(queue.count)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(isShuffled ? "Shuffled" : "Shuffle", systemImage: "shuffle", action: shuffle)
                    .disabled(!draft.heardWordIDs.isEmpty || index != 0)
                    .buttonStyle(TingXieButtonStyle(variant: .quiet))
                Button("Finish & Check", action: finishListening)
                    .disabled(draft.heardWordIDs.isEmpty)
                    .buttonStyle(TingXieButtonStyle(variant: .secondary))
            }
        }
    }

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checklist").font(.system(size: 44)).foregroundStyle(TingXiePalette.accent)
            Text("Ready to check your answers?").font(.title)
            Text("\(attemptedWords.count) words played. Compare the numbered answers with your paper.")
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
            Button("Check Answers") { draft.phase = .marking; persist() }
                .buttonStyle(TingXieButtonStyle(variant: .primary))
            if draft.heardWordIDs.count < queue.count {
                Button("Continue Dictation", action: continueListening)
                    .buttonStyle(TingXieButtonStyle(variant: .secondary))
                Text("Words you haven’t heard will stay ungraded.").font(.caption)
            }
            Spacer()
        }
        .multilineTextAlignment(.center)
    }

    private var markingView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Check your answers").font(.title)
            Text("Select incorrect or blank answers. The remaining words will be marked correct when you save.")
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(attemptedWords, id: \.recordID) { word in
                        answerRow(word)
                    }
                }
            }
            HStack {
                Text("\(correctCount) correct · \(missedCount) missed")
                    .font(.callout).monospacedDigit()
                Spacer()
                Button(isSaving ? "Saving…" : "Save Results · \(correctCount) correct, \(missedCount) missed", action: saveResults)
                    .buttonStyle(TingXieButtonStyle(variant: .primary))
                    .disabled(isSaving || attemptedWords.isEmpty)
            }
            if draft.submissionDate != nil && !isSaving {
                Text("Your answers are locked for this save. Retry Save Results to finish safely.")
                    .font(.caption)
            }
        }
    }

    private func answerRow(_ word: VocabularyWord) -> some View {
        HStack(spacing: 18) {
            Text("\((queue.firstIndex(of: word.recordID) ?? 0) + 1)")
                .font(.title3.monospacedDigit())
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 5) {
                Text(word.chinese).font(.title2.weight(.semibold))
                Text(word.pinyin).font(.callout)
                Text(word.englishTranslation).font(.callout).foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            Spacer()
            Toggle("Missed", isOn: Binding(
                get: { draft.missedWordIDs.contains(word.recordID) },
                set: { missed in
                    if missed { draft.missedWordIDs.insert(word.recordID) }
                    else { draft.missedWordIDs.remove(word.recordID) }
                    persist()
                }
            ))
            .toggleStyle(.checkbox)
            .accessibilityLabel("Mark word \((queue.firstIndex(of: word.recordID) ?? 0) + 1), \(word.chinese), missed")
            .disabled(isSaving || draft.submissionDate != nil)
        }
        .padding(18)
        .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var resultsView: some View {
        PracticeSessionSummaryView(
            sessionTitle: title,
            isDueReview: initialSession.resolvedSourceKind == .dueReview,
            summary: sessionSummary,
            onPracticeMissedWords: {
                beginFollowUp(queue.filter { draft.missedWordIDs.contains($0) })
            },
            onContinueSession: {
                beginFollowUp(queue.filter { !draft.heardWordIDs.contains($0) })
            },
            onFinish: onFinish
        )
    }

    private var sessionSummary: PracticeSessionSummaryData {
        func summaryWord(_ word: VocabularyWord) -> PracticeSessionSummaryData.Word {
            .init(id: word.persistentModelID, chinese: word.chinese, pinyin: word.pinyin)
        }
        return PracticeSessionSummaryData(
            gradedWordCount: attemptedWords.count,
            availableWordCount: queue.count,
            learnedWords: attemptedWords.filter { !draft.missedWordIDs.contains($0.recordID) }.map(summaryWord),
            missedWords: attemptedWords.filter { draft.missedWordIDs.contains($0.recordID) }.map(summaryWord)
        )
    }

    private func pause() {
        isPaused = true
        countdownTask?.cancel()
        countdownTask = nil
        audio.stop()
    }

    private func playCurrentWord() {
        guard draft.phase == .listening, let word = currentWord else { return }
        pause()
        errorMessage = nil
        remainingSeconds = nil
        repetitionsLeft = max(draft.repetitions - 1, 0)
        isPaused = false
        audio.speak(word.chinese)
    }

    private func speechFinished() {
        guard !isPaused, draft.phase == .listening, let word = currentWord else { return }
        // Count a word only after its utterance finishes.
        draft.heardWordIDs.insert(word.recordID)
        persist()
        if repetitionsLeft > 0 {
            repetitionsLeft -= 1
            audio.speak(word.chinese)
        } else {
            remainingSeconds = draft.writingSeconds
            startCountdown()
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while !Task.isCancelled, !isPaused, let remaining = remainingSeconds, remaining > 0 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled, !isPaused else { return }
                remainingSeconds = remaining - 1
            }
            guard !Task.isCancelled, !isPaused else { return }
            advance()
        }
    }

    private func previousWord() {
        guard draft.phase == .listening, index > 0 else { return }
        pause()
        remainingSeconds = nil
        index -= 1
        persist()
        playCurrentWord()
    }

    private func advance() {
        guard hasHeardCurrent else { return }
        pause()
        remainingSeconds = nil
        if index + 1 < queue.count {
            index += 1
            persist()
            playCurrentWord()
        } else { finishListening() }
    }

    private func finishListening() {
        guard !draft.heardWordIDs.isEmpty else { return }
        pause()
        remainingSeconds = nil
        draft.phase = .ready
        persist()
    }

    private func continueListening() {
        if hasHeardCurrent, index + 1 < queue.count { index += 1 }
        draft.phase = .listening
        persist()
        playCurrentWord()
    }

    private func shuffle() {
        guard draft.heardWordIDs.isEmpty, index == 0 else { return }
        pause()
        queue.shuffle()
        isShuffled = true
        persist()
        playCurrentWord()
    }

    private func beginFollowUp(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let repetitions = draft.repetitions
        let seconds = draft.writingSeconds
        draft = SavedContinuousDictation(repetitions: repetitions, writingSeconds: seconds)
        queue = ids
        index = 0
        isShuffled = false
        persist()
        playCurrentWord()
    }

    private func saveResults() {
        guard !isSaving, draft.phase == .marking, !attemptedWords.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        // Persist a stable, rounded timestamp before the actor hop for exact retry comparisons.
        if draft.submissionDate == nil {
            draft.submissionDate = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 * 1000) / 1000)
        }
        persist()
        let date = draft.submissionDate!
        let configuration = ReviewSchedulePreferences.currentConfiguration()
        let requests = attemptedWords.map { word in
            PracticeResultRequest(wordRecordID: word.recordID,
                isMissed: draft.missedWordIDs.contains(word.recordID), reviewedAt: date,
                scheduleConfiguration: configuration)
        }
        let analytics = attemptedWords.map { word in
            (key: word.chinese.tingXieTrimmed,
             setKey: word.session.map { PracticeAnalyticsStore.setKey(for: $0.dateCreated) } ?? "word-\(word.recordID.uuidString)",
             correct: !draft.missedWordIDs.contains(word.recordID))
        }
        let submissionID = draft.id
        let store = DictationStore(modelContainer: modelContext.container)
        Task {
            do {
                try await store.applyDictationResults(requests)
                PracticeAnalyticsStore.recordDictation(id: submissionID, recordedAt: date, results: analytics)
                draft.phase = .results
                persist()
            } catch {
                errorMessage = "Results couldn’t be saved. Your answers are kept; try Save Results again."
            }
            isSaving = false
        }
    }

    private func persist() {
        guard !queue.isEmpty else { return }
        PracticeSessionStore.save(SavedPracticeSession(
            version: SavedPracticeSession.currentVersion,
            sourceKind: initialSession.sourceKind, setRecordID: initialSession.setRecordID,
            filter: initialSession.filter, queueWordRecordIDs: queue, currentIndex: index,
            grades: [], isQueueShuffled: isShuffled, isCardFlipped: false,
            savedAt: Date(), dictation: draft
        ))
    }
}

// Gives the listening footer a clear, full-width track in both appearances.
private struct DictationProgressBarStyle: ProgressViewStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let progress = min(max(configuration.fractionCompleted ?? 0, 0), 1)
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(TingXiePalette.outlineVariant.opacity(0.55))
                Capsule()
                    .fill(TingXiePalette.accent)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: progress)
    }
}
