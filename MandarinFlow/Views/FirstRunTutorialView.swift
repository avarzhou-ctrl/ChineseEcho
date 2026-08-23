import SwiftUI

// Introduces the core learning loop and collects explicit consent for the optional Local AI download.
struct FirstRunTutorialView: View {
    private enum Page: Int, CaseIterable {
        case welcome
        case dictation
        case vocabulary
        case localAI
    }

    let isFirstRun: Bool
    let initialDownloadChoice: LocalAIDownloadChoice
    let onComplete: (LocalAIDownloadChoice) -> Void

    @State private var page: Page = .welcome
    @State private var downloadChoice: LocalAIDownloadChoice

    init(
        isFirstRun: Bool,
        initialDownloadChoice: LocalAIDownloadChoice,
        onComplete: @escaping (LocalAIDownloadChoice) -> Void
    ) {
        self.isFirstRun = isFirstRun
        self.initialDownloadChoice = initialDownloadChoice
        self.onComplete = onComplete
        _downloadChoice = State(
            initialValue: initialDownloadChoice == .undecided ? .download : initialDownloadChoice
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isFirstRun ? "Welcome to MandarinFlow" : "Getting Started")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("Step \(page.rawValue + 1) of \(Page.allCases.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
            }
            .padding(.horizontal, 30)
            .frame(height: 64)

            Divider()

            Group {
                switch page {
                case .welcome:
                    tutorialPage(
                        symbol: "waveform.and.person.filled",
                        title: "Listen. Learn. Remember.",
                        summary: "MandarinFlow turns your own vocabulary into focused Mandarin listening practice.",
                        points: [
                            TutorialPoint(symbol: "speaker.wave.2.fill", title: "Hear native speech", detail: "Practice with Apple’s built-in Mandarin voices."),
                            TutorialPoint(symbol: "rectangle.on.rectangle", title: "Reveal when ready", detail: "Listen first, then flip the card to check yourself."),
                            TutorialPoint(symbol: "calendar.badge.clock", title: "Remember over time", detail: "Known and missed answers shape your future reviews.")
                        ]
                    )
                case .dictation:
                    tutorialPage(
                        symbol: "headphones",
                        title: "Build Smart Dictation sets",
                        summary: "Create a set from the words you are learning, then work through an audio-first flashcard session.",
                        points: [
                            TutorialPoint(symbol: "plus.circle.fill", title: "Create a focused set", detail: "Enter Chinese words or import a prepared list."),
                            TutorialPoint(symbol: "arrow.triangle.2.circlepath", title: "Practice your way", detail: "Replay, shuffle, reveal hints, and adjust speech in Settings."),
                            TutorialPoint(symbol: "checkmark.circle.fill", title: "Grade honestly", detail: "Mark each answer Known or Missed and undo mistakes.")
                        ]
                    )
                case .vocabulary:
                    tutorialPage(
                        symbol: "character.book.closed.fill",
                        title: "Grow your Vocabulary Hub",
                        summary: "Every saved word stays organized in one place for pronunciation, editing, and focused review.",
                        points: [
                            TutorialPoint(symbol: "flag.fill", title: "Find missed words", detail: "Filter the catalog to revisit vocabulary that needs attention."),
                            TutorialPoint(symbol: "lightbulb.fill", title: "Keep learner hints", detail: "Save a short clue and reveal it only when needed."),
                            TutorialPoint(symbol: "text.bubble.fill", title: "Add real context", detail: "Generate bilingual example sentences with optional Local AI.")
                        ]
                    )
                case .localAI:
                    localAIPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                pageIndicators

                Spacer()

                if page != .welcome {
                    Button(action: moveBackward) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(OutlineCapsuleButtonStyle())
                    .accessibilityLabel("Back")
                    .help("Previous step")
                }

                if page == .localAI {
                    Button(isFirstRun ? "Finish Setup" : "Done") {
                        onComplete(downloadChoice)
                    }
                    .buttonStyle(GreenCapsuleButtonStyle())
                } else {
                    Button(action: moveForward) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(GreenCapsuleButtonStyle())
                    .accessibilityLabel("Continue")
                    .help("Next step")
                }
            }
            .padding(.horizontal, 30)
            .frame(height: 76)
        }
        .frame(width: 720, height: 570)
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
        .interactiveDismissDisabled(isFirstRun)
    }

    private func tutorialPage(
        symbol: String,
        title: String,
        summary: String,
        points: [TutorialPoint]
    ) -> some View {
        VStack(spacing: 24) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(TingXiePalette.accent)
                .frame(width: 96, height: 96)
                .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 26))

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 30, weight: .semibold))
                Text(summary)
                    .font(TingXieTypography.body)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 540)
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(points) { point in
                    TutorialPointCard(point: point)
                }
            }
            .frame(maxWidth: 620)
        }
        .padding(.horizontal, 30)
    }

    private var localAIPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(TingXiePalette.accent)
                .frame(width: 88, height: 88)
                .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 7) {
                Text("Optional private Local AI")
                    .font(.system(size: 29, weight: .semibold))
                Text("\(LocalModelSpec.displayName) can fill vocabulary details and create contextual sentences entirely on this Mac.")
                    .font(TingXieTypography.body)
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 550)
            }

            VStack(spacing: 10) {
                downloadChoiceButton(
                    .download,
                    title: "Download Local AI",
                    detail: "About \(LocalModelSpec.estimatedDownloadSizeText) · Download continues in the background.",
                    symbol: "arrow.down.circle.fill"
                )
                downloadChoiceButton(
                    .notNow,
                    title: "Not Now",
                    detail: "Dictation, speech, grading, reviews, and manual entry remain fully available.",
                    symbol: "clock.fill"
                )
            }
            .frame(maxWidth: 590)

            Label("The model and generated text stay on this Mac.", systemImage: "lock.shield.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
        }
        .padding(.horizontal, 30)
    }

    private func downloadChoiceButton(
        _ choice: LocalAIDownloadChoice,
        title: String,
        detail: String,
        symbol: String
    ) -> some View {
        Button {
            downloadChoice = choice
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(downloadChoice == choice ? .white : TingXiePalette.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        downloadChoice == choice ? TingXiePalette.accent : TingXiePalette.surfaceContainerHigh,
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: downloadChoice == choice ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(downloadChoice == choice ? TingXiePalette.accent : TingXiePalette.outline)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        downloadChoice == choice ? TingXiePalette.accent : TingXiePalette.outlineVariant,
                        lineWidth: downloadChoice == choice ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(downloadChoice == choice ? .isSelected : [])
    }

    private var pageIndicators: some View {
        HStack(spacing: 7) {
            ForEach(Page.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == page ? TingXiePalette.accent : TingXiePalette.outlineVariant)
                    .frame(width: item == page ? 22 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutorial step \(page.rawValue + 1) of \(Page.allCases.count)")
    }

    private func moveForward() {
        guard let next = Page(rawValue: page.rawValue + 1) else { return }
        page = next
    }

    private func moveBackward() {
        guard let previous = Page(rawValue: page.rawValue - 1) else { return }
        page = previous
    }
}

// Carries one concise learning benefit into a reusable tutorial card.
private struct TutorialPoint: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

// Keeps tutorial explanations visually balanced and easy to scan.
private struct TutorialPointCard: View {
    let point: TutorialPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: point.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TingXiePalette.accent)
            Text(point.title)
                .font(.system(size: 13, weight: .semibold))
            Text(point.detail)
                .font(.system(size: 11))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("First Run Tutorial") {
    FirstRunTutorialView(isFirstRun: true, initialDownloadChoice: .undecided) { _ in }
}
