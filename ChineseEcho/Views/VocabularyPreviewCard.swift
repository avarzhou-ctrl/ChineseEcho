//
//  VocabularyPreviewCard.swift
//  ChineseEcho
//

import SwiftData
import SwiftUI

// Freezes the fields the compact preview needs so a finished session keeps showing
// what the learner practiced even if the underlying record changes afterwards.
struct VocabularyPreviewSnapshot: Identifiable, Equatable {
    let id: PersistentIdentifier
    let chinese: String
    let pinyin: String
    let englishTranslation: String
    let learnerHint: String?
    let isIdiom: Bool
    let isMissedWord: Bool
    let tags: [String]
    let generatedSentence: String?

    init(word: VocabularyWord) {
        id = word.persistentModelID
        chinese = word.chinese
        pinyin = word.pinyin
        englishTranslation = word.englishTranslation
        learnerHint = word.learnerHint
        isIdiom = word.isIdiom
        isMissedWord = word.isMissedWord
        tags = word.tags
        generatedSentence = word.generatedSentence
    }

    var contextualSentences: [ContextualSentence] {
        ContextualSentencePayload.storedExamples(from: generatedSentence)
    }

    var meaningText: String {
        englishTranslation.isEmpty
            ? "No translation yet"
            : englishTranslation.vocabularyDefinitionDisplayText
    }
}

// Mirrors the Vocabulary Hub inspector at popover scale: the same characters, pinyin,
// playback, tags, meaning, hint, and contextual sentence, without the editing controls.
struct VocabularyPreviewCard: View {
    let snapshot: VocabularyPreviewSnapshot
    let showsMissed: Bool

    @State private var audioEngine = SpeechAudioEngine()

    // Two sentences overflow a hover card, so the preview commits to the first one.
    private var previewSentence: ContextualSentence? {
        snapshot.contextualSentences.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(snapshot.chinese.tingXieVocabularyDisplayText)
                    .font(TingXieTypography.vocabulary(size: snapshot.chinese.count > 3 ? 28 : 34, weight: .bold))
                    .foregroundStyle(TingXiePalette.accent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Spacer(minLength: 4)

                PreviewTagRow(snapshot: snapshot, showsMissed: showsMissed)
            }

            HStack(spacing: 8) {
                Text(snapshot.pinyin.isEmpty ? "No pinyin" : snapshot.pinyin)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TingXiePalette.onBackground)

                Button {
                    audioEngine.togglePlayback(of: snapshot.chinese)
                } label: {
                    Image(
                        systemName: audioEngine.isSpeaking
                            ? "stop.fill"
                            : "speaker.wave.2.fill"
                    )
                }
                .buttonStyle(
                    TingXieButtonStyle(
                        variant: .secondary,
                        size: .compact,
                        isIconOnly: true
                    )
                )
                .help(audioEngine.isSpeaking ? "Stop playback" : "Play \(snapshot.chinese)")
                .accessibilityLabel(
                    audioEngine.isSpeaking ? "Stop playback" : "Play \(snapshot.chinese)"
                )

                Spacer(minLength: 0)
            }
            .padding(.top, 6)

            Divider()
                .overlay(TingXiePalette.outlineVariant.opacity(0.5))
                .padding(.vertical, 12)

            PreviewSectionTitle("Meaning")
            Text(snapshot.meaningText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TingXiePalette.onBackground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            if let learnerHint = snapshot.learnerHint?.tingXieNilIfEmpty {
                PreviewSectionTitle("Learner Hint")
                    .padding(.top, 14)
                Label(learnerHint, systemImage: "lightbulb.fill")
                    .font(TingXieTypography.metadata)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }

            PreviewSectionTitle("Example Sentences")
                .padding(.top, 14)

            if let previewSentence {
                ContextualSentenceCard(
                    example: previewSentence,
                    chineseVocabulary: snapshot.chinese,
                    englishMeaning: snapshot.englishTranslation.vocabularyDefinitionDisplayText,
                    compact: true
                )
                .padding(.top, 7)
            } else {
                Text("No examples yet — open Vocabulary to create them.")
                    .font(TingXieTypography.metadata)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }
        }
        .padding(18)
        .frame(width: 340, alignment: .leading)
        .background(TingXiePalette.background)
        .onAppear { audioEngine.configureFromPreferences() }
        .onDisappear { audioEngine.stop() }
    }
}

// Repeats the hub's tag capsules at the smaller hover-card scale.
private struct PreviewTagRow: View {
    let snapshot: VocabularyPreviewSnapshot
    let showsMissed: Bool

    var body: some View {
        HStack(spacing: 5) {
            if snapshot.isIdiom { TagLabel(text: "Idiom", color: .orange, compact: true) }
            if showsMissed || snapshot.isMissedWord {
                TagLabel(text: "Missed", color: TingXiePalette.missed, compact: true)
            }
            if let tag = snapshot.tags.first {
                TagLabel(text: tag, color: TingXiePalette.secondary, compact: true)
            }
        }
    }
}

// Matches the inspector's section headings one step down in scale.
private struct PreviewSectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.15)
            .foregroundStyle(TingXiePalette.secondary.opacity(0.65))
    }
}

// Opens the compact preview after a deliberate hover so passing the pointer across a
// word list never flashes cards, and keeps it open while the pointer moves into it.
private struct VocabularyHoverPreview: ViewModifier {
    let snapshot: VocabularyPreviewSnapshot
    let showsMissed: Bool
    let arrowEdge: Edge

    private static let openDelay = Duration.milliseconds(420)
    private static let closeDelay = Duration.milliseconds(180)

    // @State keeps one pending open/close timer per row; a new hover replaces it.
    @State private var isPresented = false
    @State private var isPointerInsideCard = false
    @State private var transitionTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering {
                    schedule(presented: true, after: Self.openDelay)
                } else {
                    schedule(presented: false, after: Self.closeDelay)
                }
            }
            .popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                VocabularyPreviewCard(snapshot: snapshot, showsMissed: showsMissed)
                    .onHover { isHovering in
                        isPointerInsideCard = isHovering
                        if isHovering {
                            transitionTask?.cancel()
                        } else {
                            schedule(presented: false, after: Self.closeDelay)
                        }
                    }
            }
            .onDisappear {
                transitionTask?.cancel()
                transitionTask = nil
            }
    }

    private func schedule(presented: Bool, after delay: Duration) {
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            // Closing must not fight the pointer that just moved onto the card itself.
            guard presented || !isPointerInsideCard else { return }
            isPresented = presented
        }
    }
}

extension View {
    // Attaches the Vocabulary Hub preview to any row that represents a saved word.
    func vocabularyHoverPreview(
        _ snapshot: VocabularyPreviewSnapshot,
        showsMissed: Bool = false,
        arrowEdge: Edge = .trailing
    ) -> some View {
        modifier(
            VocabularyHoverPreview(
                snapshot: snapshot,
                showsMissed: showsMissed,
                arrowEdge: arrowEdge
            )
        )
    }
}
