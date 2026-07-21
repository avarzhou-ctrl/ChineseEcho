import AVFoundation
import SwiftData
import SwiftUI

struct SmartDictationView: View {
    let sets: [DictationSet]
    let activeSet: DictationSet?
    let onCreateSet: () -> Void
    let onOpenSet: (DictationSet) -> Void
    let onCloseSet: () -> Void

    var body: some View {
        Group {
            if let activeSet {
                PracticeSessionView(set: activeSet, onFinish: onCloseSet)
            } else {
                VStack(spacing: 0) {
                    WorkspaceHeader(
                        title: "Smart Dictation",
                        showsAddButton: !sets.isEmpty,
                        addAction: onCreateSet
                    )

                    if sets.isEmpty {
                        EmptyDictationView(onCreateSet: onCreateSet)
                    } else {
                        DictationSetList(sets: sets, onOpenSet: onOpenSet)
                    }
                }
            }
        }
        .background(TingXiePalette.workspace)
    }
}

private struct EmptyDictationView: View {
    let onCreateSet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "waveform.badge.microphone")
                .font(.system(size: 146, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(TingXiePalette.accent)

            Text("No Sessions Yet")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(TingXiePalette.accent)
                .padding(.top, 24)

            Text("Create your first custom practice round to\nstart testing your vocabulary.")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            Button(action: onCreateSet) {
                Label("Create New Set", systemImage: "plus")
            }
            .buttonStyle(GreenCapsuleButtonStyle())
            .padding(.top, 16)

            Spacer()
                .frame(maxHeight: 190)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DictationSetList: View {
    let sets: [DictationSet]
    let onOpenSet: (DictationSet) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sets) { set in
                    Button {
                        onOpenSet(set)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(TingXiePalette.accent)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(set.title)
                                    .font(.system(size: 24, weight: .medium))
                                Text(set.dateCreated, format: .dateTime.month(.twoDigits).day(.twoDigits).year())
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(TingXiePalette.accent.opacity(0.35))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 16)
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
    @State private var audioEngine = SpeechAudioEngine()

    private var words: [VocabularyWord] {
        switch filter {
        case .all: set.vocabularyWords
        case .missed: set.vocabularyWords.filter(\.isMissedWord)
        case .idioms: set.vocabularyWords.filter(\.isIdiom)
        }
    }

    private var currentWord: VocabularyWord? {
        guard words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: set.title)

            Divider()
                .overlay(TingXiePalette.accent.opacity(0.35))
                .padding(.horizontal, 24)
                .padding(.top, 8)

            Picker("Vocabulary Filter", selection: $filter) {
                ForEach(PracticeFilter.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .onChange(of: filter) { _, _ in
                currentIndex = 0
                revealsCharacters = false
            }

            Group {
                if words.isEmpty {
                    ContentUnavailableView(
                        "No Words in This Filter",
                        systemImage: "text.magnifyingglass",
                        description: Text("Choose a different category to continue practicing.")
                    )
                } else {
                    practiceCard
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(TingXiePalette.workspace)
        .onAppear {
            audioEngine.selectedVoice = audioEngine.voices.first
        }
    }

    private var practiceCard: some View {
        VStack(spacing: 16) {
            ScrollView {
                FlowLayout(spacing: 18) {
                    ForEach(Array(words.enumerated()), id: \.element.persistentModelID) { index, word in
                        Text(revealsCharacters ? word.chinese : word.pinyin)
                            .font(.system(size: revealsCharacters ? 20 : 18, weight: index == currentIndex ? .bold : .regular))
                            .foregroundStyle(word.isMissedWord && revealsCharacters ? TingXiePalette.missed : .primary)
                            .onTapGesture {
                                currentIndex = index
                                speakCurrentWord()
                            }
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 10) {
                ProgressView(value: Double(currentIndex + 1), total: Double(max(words.count, 1)))
                    .tint(TingXiePalette.accent)

                Button(action: speakCurrentWord) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(TingXiePalette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play Current Word")
            }

            HStack {
                Button {
                    revealsCharacters.toggle()
                } label: {
                    Label(revealsCharacters ? "Hide Characters" : "Reveal Characters", systemImage: revealsCharacters ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(GreenCapsuleButtonStyle())

                Spacer()

                if revealsCharacters {
                    Button {
                        markCurrentWordMissed()
                    } label: {
                        Label("Mark Missed", systemImage: "xmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TingXiePalette.missed)

                    Button(action: onFinish) {
                        Label("Finish Set", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TingXiePalette.accent)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    private func speakCurrentWord() {
        guard let currentWord else { return }
        audioEngine.stop()
        audioEngine.speak(currentWord.chinese)
    }

    private func markCurrentWordMissed() {
        guard let currentWord else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        let wordID = currentWord.persistentModelID
        Task {
            try? await store.setMissed(true, wordID: wordID)
            if currentIndex < words.count - 1 {
                currentIndex += 1
                revealsCharacters = false
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var point = CGPoint.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x + size.width > width, point.x > 0 {
                point.x = 0
                point.y += lineHeight + spacing
                lineHeight = 0
            }
            point.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: point.y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
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
        VStack(alignment: .leading, spacing: 18) {
            Text("Create New Set")
                .font(.largeTitle.bold())
                .foregroundStyle(TingXiePalette.accent)

            TextField("Set name", text: $title)

            VStack(alignment: .leading, spacing: 6) {
                Text("Words")
                    .font(.headline)
                Text("Enter one item per line: Chinese | pinyin | translation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $sourceText)
                    .font(.body.monospaced())
                    .padding(8)
                    .frame(minHeight: 210)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(TingXiePalette.accent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedWords.isEmpty || isSaving)
            }
        }
        .padding(28)
        .frame(width: 560, height: 440)
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
