import SwiftData
import SwiftUI

private enum VocabularyFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .all: "list.bullet"
        case .missed: "xmark.circle.fill"
        case .idioms: "scroll.fill"
        }
    }
}

struct VocabularyHubView: View {
    let words: [VocabularyWord]

    @State private var searchText = ""
    @State private var filter: VocabularyFilter = .all
    @State private var selectedWordID: PersistentIdentifier?

    private var filteredWords: [VocabularyWord] {
        words.filter { word in
            let matchesFilter = switch filter {
            case .all: true
            case .missed: word.isMissedWord
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
           let selected = words.first(where: { $0.persistentModelID == selectedWordID }) {
            return selected
        }
        return filteredWords.first
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                WorkspaceHeader(title: "Your Vocabulary Hub")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Search vocabulary, pinyin, tags...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                }
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 24)

                vocabularyPicker
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                if filteredWords.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    vocabularyList
                }
            }
            .frame(minWidth: 430, idealWidth: 490)

            VocabularyInspector(word: selectedWord)
                .frame(minWidth: 260, idealWidth: 310)
        }
        .background(TingXiePalette.workspace)
    }

    private var vocabularyPicker: some View {
        HStack(spacing: 0) {
            ForEach(VocabularyFilter.allCases) { item in
                Button {
                    filter = item
                    selectedWordID = nil
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 22, weight: .medium))
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .foregroundStyle(.primary)
                    .background(filter == item ? TingXiePalette.surface : .clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(TingXiePalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var vocabularyList: some View {
        List {
            ForEach(Array(filteredWords.enumerated()), id: \.element.persistentModelID) { index, word in
                HStack(spacing: 0) {
                    Text(word.chinese)
                        .frame(width: 129, alignment: .leading)

                    Text(word.pinyin)
                        .frame(width: 157, alignment: .leading)

                    WordTags(word: word, compact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedWordID = word.persistentModelID
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(index.isMultiple(of: 2) ? TingXiePalette.surface : TingXiePalette.tableStripe)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TingXiePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
}

private struct VocabularyInspector: View {
    @Environment(\.modelContext) private var modelContext

    let word: VocabularyWord?

    @State private var isGenerating = false
    @State private var generationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(TingXiePalette.accent)
            }

            if let word {
                Text(word.chinese)
                    .font(.system(size: 44, weight: .bold))
                    .padding(.top, 8)
                Text(word.pinyin)
                    .font(.title3)

                WordTags(word: word, compact: false)
                    .padding(.top, 8)

                Text(word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation)
                    .font(.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 16)

                HStack {
                    Text("Contextual Sentences")
                        .font(.title3.bold())
                    Spacer()
                    Button(action: regenerateSentence) {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TingXiePalette.accent)
                    .disabled(isGenerating)
                    .accessibilityLabel("Regenerate Sentences")
                }
                .padding(.top, 28)

                Text(word.generatedSentence ?? "Generate a natural example sentence for this word from the vocabulary tools.")
                    .font(.callout)
                    .lineSpacing(5)
                    .padding(.top, 10)

                if let generationError {
                    Text(generationError)
                        .font(.caption)
                        .foregroundStyle(TingXiePalette.missed)
                        .padding(.top, 8)
                }

                Spacer()

                Divider()
                HStack {
                    if word.isMissedWord {
                        Label("Missed", systemImage: "flag.fill")
                            .foregroundStyle(TingXiePalette.missed)
                    }
                    Spacer()
                    Button("Mark As Learned", systemImage: "checkmark", action: markAsLearned)
                        .buttonStyle(.borderedProminent)
                        .tint(TingXiePalette.accent)
                        .disabled(!word.isMissedWord)
                }
                .font(.caption)
                .padding(.top, 8)
            } else {
                ContentUnavailableView(
                    "No Vocabulary Yet",
                    systemImage: "character.book.closed",
                    description: Text("Words from your dictation sets will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
        .background(TingXiePalette.workspace)
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

    private func markAsLearned() {
        guard let word else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        let wordID = word.persistentModelID
        Task {
            try? await store.setMissed(false, wordID: wordID)
        }
    }
}

private struct WordTags: View {
    let word: VocabularyWord
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            if word.isIdiom {
                TagLabel(text: "Idiom", color: .orange, compact: compact)
            }
            if word.isMissedWord {
                TagLabel(text: "Missed", color: TingXiePalette.missed, compact: compact)
            }
            if let tag = word.tags.first {
                TagLabel(text: tag, color: TingXiePalette.accent, compact: compact)
            }
        }
    }
}

private struct TagLabel: View {
    let text: String
    let color: Color
    let compact: Bool

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 8 : 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 4 : 6)
            .frame(height: compact ? 16 : 21)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            .lineLimit(1)
    }
}

struct SettingsDashboard: View {
    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(title: "Settings")

            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink {
                        SpeechTestView()
                    } label: {
                        SettingsCard(
                            title: "Speech & Pronunciation",
                            description: "Choose a Mandarin voice and adjust dictation speed and pitch.",
                            symbol: "speaker.wave.2.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LLMTestView()
                    } label: {
                        SettingsCard(
                            title: "Local Language Model",
                            description: "Test Qwen generation running privately on this Mac with MLX.",
                            symbol: "cpu.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
            }
        }
        .background(TingXiePalette.workspace)
    }
}

private struct SettingsCard: View {
    let title: String
    let description: String
    let symbol: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(TingXiePalette.accent)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(description).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Vocabulary Hub — Empty") {
    VocabularyHubView(words: [])
        .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

@MainActor
private func populatedVocabularyHubPreview() -> some View {
    let setTitle = "HSK 5 full set"
    let idiom = VocabularyWord(
        chinese: "莫名其妙",
        englishTranslation: "Baffling; without rhyme or reason",
        pinyin: "mò míng qí miào",
        isMissedWord: true,
        isIdiom: true,
        tags: [setTitle]
    )
    idiom.generatedSentence = "他今天突然朝我发脾气，真是莫名其妙。"

    let words = [
        idiom,
        VocabularyWord(chinese: "把握", englishTranslation: "to grasp", pinyin: "bǎ wò", tags: [setTitle]),
        VocabularyWord(chinese: "集中", englishTranslation: "to concentrate", pinyin: "jí zhōng", isMissedWord: true, tags: [setTitle]),
        VocabularyWord(chinese: "核心", englishTranslation: "core", pinyin: "hé xīn", tags: [setTitle]),
        VocabularyWord(chinese: "反复", englishTranslation: "repeatedly", pinyin: "fǎn fù", tags: [setTitle]),
        VocabularyWord(chinese: "必然", englishTranslation: "inevitable", pinyin: "bì rán", tags: [setTitle])
    ]

    return VocabularyHubView(words: words)
        .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Vocabulary Hub — Populated") {
    populatedVocabularyHubPreview()
}
