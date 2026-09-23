import SwiftUI

// Identifies real controls that the guided tour can reveal without duplicating the app UI.
enum TutorialTarget: Hashable {
    case dictationSidebar
    case vocabularySidebar
    case settingsSidebar
    case createSetButton
    case vocabularyFilters
    case voicePreviewButton
}

// Collects target geometry from whichever workspace is currently visible.
struct TutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TutorialTarget: Anchor<CGRect>],
        nextValue: () -> [TutorialTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

extension View {
    // Registers a control as a spotlight target in the coordinate space of the app window.
    func tutorialTarget(_ target: TutorialTarget?) -> some View {
        anchorPreference(key: TutorialTargetPreferenceKey.self, value: .bounds) { anchor in
            guard let target else { return [:] }
            return [target: anchor]
        }
    }
}

// Guides the learner through the actual app while collecting the optional Local AI choice.
struct FirstRunTutorialView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case dictationNavigation
        case createSet
        case vocabularyNavigation
        case vocabularyFilters
        case settingsNavigation
        case voicePreview
        case localAI

        var section: AppSection {
            switch self {
            case .welcome, .dictationNavigation, .createSet:
                .dictation
            case .vocabularyNavigation, .vocabularyFilters:
                .vocabulary
            case .settingsNavigation, .voicePreview, .localAI:
                .settings
            }
        }

        var target: TutorialTarget? {
            switch self {
            case .welcome, .localAI: nil
            case .dictationNavigation: .dictationSidebar
            case .createSet: .createSetButton
            case .vocabularyNavigation: .vocabularySidebar
            case .vocabularyFilters: .vocabularyFilters
            case .settingsNavigation: .settingsSidebar
            case .voicePreview: .voicePreviewButton
            }
        }

        var symbol: String {
            switch self {
            case .welcome: "waveform.and.person.filled"
            case .dictationNavigation: "headphones"
            case .createSet: "plus"
            case .vocabularyNavigation: "character.book.closed.fill"
            case .vocabularyFilters: "line.3.horizontal.decrease.circle.fill"
            case .settingsNavigation: "gearshape.fill"
            case .voicePreview: "play.fill"
            case .localAI: "cpu.fill"
            }
        }

        var title: String {
            switch self {
            case .welcome: "Welcome to ChineseEcho"
            case .dictationNavigation: "Start in Smart Dictation"
            case .createSet: "Create your first set"
            case .vocabularyNavigation: "Find all your words"
            case .vocabularyFilters: "Filter your vocabulary"
            case .settingsNavigation: "Adjust your settings"
            case .voicePreview: "Preview a voice"
            case .localAI: "Local AI is optional"
            }
        }

        var detail: String {
            switch self {
            case .welcome:
                "Here’s where to create a set, practice words, and adjust speech."
            case .dictationNavigation:
                "Create listening sets and review words when they’re due."
            case .createSet:
                "Use this plus button to type Chinese words or import a list."
            case .vocabularyNavigation:
                "Vocabulary collects words from every set and flags the ones you miss."
            case .vocabularyFilters:
                "Show all words, missed words, or idioms."
            case .settingsNavigation:
                "Change the voice and practice options, manage Local AI, or back up your data."
            case .voicePreview:
                "Choose Mainland or Taiwanese Mandarin, adjust the sound, then press Preview Voice."
            case .localAI:
                "It can add pinyin, meanings, and example sentences without sending your text off this Mac."
            }
        }
    }

    let isFirstRun: Bool
    let initialDownloadChoice: LocalAIDownloadChoice
    let targetFrames: [TutorialTarget: CGRect]
    let containerSize: CGSize
    let onNavigate: (AppSection) -> Void
    let onComplete: (LocalAIDownloadChoice) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @State private var downloadChoice: LocalAIDownloadChoice

    init(
        isFirstRun: Bool,
        initialDownloadChoice: LocalAIDownloadChoice,
        targetFrames: [TutorialTarget: CGRect],
        containerSize: CGSize,
        onNavigate: @escaping (AppSection) -> Void,
        onComplete: @escaping (LocalAIDownloadChoice) -> Void
    ) {
        self.isFirstRun = isFirstRun
        self.initialDownloadChoice = initialDownloadChoice
        self.targetFrames = targetFrames
        self.containerSize = containerSize
        self.onNavigate = onNavigate
        self.onComplete = onComplete
        _downloadChoice = State(
            initialValue: initialDownloadChoice == .undecided ? .download : initialDownloadChoice
        )
    }

    var body: some View {
        ZStack {
            spotlightMask

            callout
                .frame(width: panelWidth)
                .position(calloutPosition)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .foregroundStyle(TingXiePalette.onBackground)
        .accessibilityAddTraits(.isModal)
        .onAppear { onNavigate(step.section) }
        .onChange(of: step) { _, newStep in
            onNavigate(newStep.section)
        }
        .onExitCommand {
            guard !isFirstRun else { return }
            onComplete(downloadChoice)
        }
    }

    private var highlightedFrame: CGRect? {
        guard let target = step.target else { return nil }
        return targetFrames[target]?.insetBy(dx: -8, dy: -8)
    }

    private var spotlightMask: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: containerSize))
            if let highlightedFrame {
                path.addRoundedRect(
                    in: highlightedFrame,
                    cornerSize: CGSize(width: 15, height: 15)
                )
            }
        }
        .fill(.black.opacity(0.52), style: FillStyle(eoFill: highlightedFrame != nil))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: highlightedFrame)
    }

    private var panelWidth: CGFloat {
        min(step == .localAI ? 430 : 360, max(300, containerSize.width - 48))
    }

    private var estimatedPanelHeight: CGFloat {
        switch step {
        case .localAI: 430
        case .welcome: 270
        default: 270
        }
    }

    private var calloutPosition: CGPoint {
        guard let frame = highlightedFrame else {
            return CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        }

        let margin: CGFloat = 24
        let gap: CGFloat = 20
        let halfWidth = panelWidth / 2
        let halfHeight = estimatedPanelHeight / 2
        let clampedY = min(
            max(frame.midY, margin + halfHeight),
            containerSize.height - margin - halfHeight
        )

        if containerSize.width - frame.maxX >= panelWidth + gap + margin {
            return CGPoint(x: frame.maxX + gap + halfWidth, y: clampedY)
        }
        if frame.minX >= panelWidth + gap + margin {
            return CGPoint(x: frame.minX - gap - halfWidth, y: clampedY)
        }

        let clampedX = min(
            max(frame.midX, margin + halfWidth),
            containerSize.width - margin - halfWidth
        )
        if containerSize.height - frame.maxY >= estimatedPanelHeight + gap + margin {
            return CGPoint(x: clampedX, y: frame.maxY + gap + halfHeight)
        }
        return CGPoint(x: clampedX, y: frame.minY - gap - halfHeight)
    }

    private var callout: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: step.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 42, height: 42)
                    .background(
                        TingXiePalette.lightGreenSurface,
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                        .font(TingXieTypography.eyebrow)
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    Text(step.title)
                        .font(.system(size: 22, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if isFirstRun {
                    if step != .localAI {
                        Button("Skip Tour") {
                            move(to: .localAI)
                        }
                        .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact))
                    }
                } else {
                    Button {
                        onComplete(downloadChoice)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact, isIconOnly: true))
                    .accessibilityLabel("Close tutorial")
                }
            }

            Text(step.detail)
                .font(TingXieTypography.body)
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if step == .localAI {
                localAIChoices
            }

            HStack(spacing: 12) {
                progressIndicators

                Spacer()

                if step != .welcome {
                    Button(action: moveBackward) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(TingXieButtonStyle(variant: .secondary, isIconOnly: true))
                    .accessibilityLabel("Previous step")
                }

                if step == .localAI {
                    Button(isFirstRun ? "Finish Setup" : "Done") {
                        onComplete(downloadChoice)
                    }
                    .buttonStyle(TingXieButtonStyle())
                } else {
                    Button(action: moveForward) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(TingXieButtonStyle(isIconOnly: true))
                    .accessibilityLabel("Next step")
                }
            }
        }
        .padding(22)
        .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(TingXiePalette.outlineVariant, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
    }

    private var localAIChoices: some View {
        VStack(spacing: 10) {
            choiceButton(
                .download,
                title: "Download Local AI",
                detail: "About \(LocalModelSpec.estimatedDownloadSizeText) · Continues in the background.",
                symbol: "arrow.down.circle.fill"
            )
            choiceButton(
                .notNow,
                title: "Not Now",
                detail: "Download it later in Settings. Dictation and manual entry work without it.",
                symbol: "clock.fill"
            )

            Label("The model and generated text stay on this Mac.", systemImage: "lock.shield.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
        }
    }

    private func choiceButton(
        _ choice: LocalAIDownloadChoice,
        title: String,
        detail: String,
        symbol: String
    ) -> some View {
        Button {
            downloadChoice = choice
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(downloadChoice == choice ? .white : TingXiePalette.accent)
                    .frame(width: 38, height: 38)
                    .background(
                        downloadChoice == choice
                            ? TingXiePalette.accent
                            : TingXiePalette.surfaceContainerHigh,
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: downloadChoice == choice ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        downloadChoice == choice ? TingXiePalette.accent : TingXiePalette.outline
                    )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                TingXiePalette.lightGreenSurface,
                in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
                    .stroke(
                        downloadChoice == choice
                            ? TingXiePalette.accent
                            : TingXiePalette.outlineVariant,
                        lineWidth: downloadChoice == choice ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(downloadChoice == choice ? .isSelected : [])
    }

    private var progressIndicators: some View {
        HStack(spacing: 5) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == step ? TingXiePalette.accent : TingXiePalette.outlineVariant)
                    .frame(width: item == step ? 18 : 5, height: 5)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutorial step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private func moveForward() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        move(to: next)
    }

    private func moveBackward() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        move(to: previous)
    }

    private func move(to newStep: Step) {
        if reduceMotion {
            step = newStep
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                step = newStep
            }
        }
    }
}

#Preview("Guided First Run") {
    FirstRunTutorialView(
        isFirstRun: true,
        initialDownloadChoice: .undecided,
        targetFrames: [.createSetButton: CGRect(x: 950, y: 610, width: 52, height: 52)],
        containerSize: CGSize(width: 1180, height: 720),
        onNavigate: { _ in },
        onComplete: { _ in }
    )
    .frame(width: 1180, height: 720)
    .background(TingXiePalette.background)
}
