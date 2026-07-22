import SwiftData
import SwiftUI

private enum VocabularyFilter: String, CaseIterable, Identifiable {
    case all = "All Words"
    case missed = "Missed Words"
    case idioms = "Idioms"

    var id: Self { self }
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
                subtitle: "Review every word saved from Smart Dictation.",
                searchText: $searchText,
                searchPrompt: "Search characters, pinyin, or tags…"
            )

            HSplitView {
                vocabularyCatalog
                    .frame(minWidth: 390, idealWidth: 440)

                VocabularyInspector(word: selectedWord)
                    .frame(minWidth: 360, idealWidth: 500)
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
    }

    private var vocabularyCatalog: some View {
        VStack(spacing: 20) {
            VocabularyFilterBar(selection: $filter)

            if filteredWords.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Vocabulary Yet" : "No Matching Vocabulary",
                    systemImage: "character.book.closed",
                    description: Text(searchText.isEmpty ? "Words from your dictation sets will appear here." : "Try another character, pinyin spelling, or set tag.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredWords) { word in
                            VocabularyRow(
                                word: word,
                                isSelected: word.persistentModelID == selectedWord?.persistentModelID
                            ) {
                                selectedWordID = word.persistentModelID
                            }
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
}

private struct VocabularyFilterBar: View {
    @Binding var selection: VocabularyFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(VocabularyFilter.allCases) { item in
                Button(item.rawValue) { selection = item }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(selection == item ? TingXiePalette.accent : TingXiePalette.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selection == item ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(4)
        .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct VocabularyRow: View {
    let word: VocabularyWord
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(word.chinese)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(word.isMissedWord ? TingXiePalette.missed : TingXiePalette.onBackground)
                    .frame(minWidth: 78, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(word.pinyin.isEmpty ? "No pinyin" : word.pinyin)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    WordTags(word: word, compact: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

                            WordTags(word: word, compact: false)
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

                        Button("Mark As Learned", systemImage: "checkmark.circle", action: markAsLearned)
                            .buttonStyle(GreenCapsuleButtonStyle())
                            .frame(maxWidth: .infinity)
                            .disabled(!word.isMissedWord)
                            .padding(.top, 34)
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
        .onAppear { audioEngine.selectedVoice = audioEngine.defaultFemaleVoice }
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

    private func markAsLearned() {
        guard let word else { return }
        let store = DictationStore(modelContainer: modelContext.container)
        let wordID = word.persistentModelID
        Task { try? await store.setMissed(false, wordID: wordID) }
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

    var body: some View {
        HStack(spacing: 5) {
            if word.isIdiom { TagLabel(text: "Idiom", color: .orange, compact: compact) }
            if word.isMissedWord { TagLabel(text: "Missed", color: TingXiePalette.missed, compact: compact) }
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

struct SettingsDashboard: View {
    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(
                title: "Settings",
                subtitle: "Configure and test TingXieFlow’s private, on-device learning tools."
            )

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 20)], spacing: 20) {
                    NavigationLink { SpeechTestView() } label: {
                        SettingsFeatureCard(
                            title: "Speech & Pronunciation",
                            description: "Choose an installed Mandarin voice and tune dictation speed and pitch.",
                            detail: "Apple speech synthesis",
                            symbol: "mic.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink { LLMTestView() } label: {
                        SettingsFeatureCard(
                            title: "Local Language Model",
                            description: "Test contextual sentence generation running privately on this Mac.",
                            detail: "Qwen 3 0.6B · MLX",
                            symbol: "cpu.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
    }
}

private struct SettingsFeatureCard: View {
    let title: String
    let description: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 46, height: 46)
                    .background(TingXiePalette.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 13))
                Text(title)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
                Spacer()
            }

            Text(description)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .lineSpacing(3)

            Spacer(minLength: 12)

            HStack {
                Label(detail, systemImage: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(TingXiePalette.secondary)
                Spacer()
                Label("Open Diagnostics", systemImage: "arrow.right")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .tonalCard(cornerRadius: 20)
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
    return VocabularyHubView(words: words)
        .modelContainer(for: [DictationSet.self, VocabularyWord.self], inMemory: true)
}

#Preview("Vocabulary Hub — Populated") {
    populatedVocabularyHubPreview()
}
