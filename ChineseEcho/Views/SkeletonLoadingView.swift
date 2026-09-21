import SwiftData
import SwiftUI

// Confirms the local SwiftData store can be read before replacing workspace skeletons with real content.
@ModelActor
actor LibraryReadinessProbe {
    func verifyReadable() throws {
        var setDescriptor = FetchDescriptor<DictationSet>()
        setDescriptor.fetchLimit = 1
        _ = try modelContext.fetch(setDescriptor)

        var wordDescriptor = FetchDescriptor<VocabularyWord>()
        wordDescriptor.fetchLimit = 1
        _ = try modelContext.fetch(wordDescriptor)
    }
}

// Draws one reusable placeholder with a motion-aware shimmer.
struct SkeletonBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShimmering = false

    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(TingXiePalette.surfaceContainerHigh)
            .frame(width: width, height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.58), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(geometry.size.width * 0.7, 80))
                        .offset(
                            x: isShimmering
                                ? geometry.size.width
                                : -max(geometry.size.width, 80)
                        )
                    }
                    .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    isShimmering = true
                }
            }
            .accessibilityHidden(true)
    }
}

// Mirrors each top-level workspace while its local data and supporting metadata become readable.
struct WorkspaceSkeletonView: View {
    let section: AppSection

    var body: some View {
        VStack(spacing: 0) {
            skeletonHeader

            switch section {
            case .dictation:
                dictationSkeleton
            case .vocabulary:
                vocabularySkeleton
            case .settings:
                settingsSkeleton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TingXiePalette.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading \(section.accessibilityTitle)")
    }

    private var skeletonHeader: some View {
        HStack {
            SkeletonBlock(width: section == .vocabulary ? 330 : 230, height: 38, cornerRadius: 10)
            Spacer()
            if section != .settings {
                SkeletonBlock(
                    width: 310,
                    height: TingXieControlMetrics.regularHeight,
                    cornerRadius: TingXieControlMetrics.controlCornerRadius
                )
            }
            SkeletonBlock(width: 40, height: 40, cornerRadius: 20)
        }
        .padding(.horizontal, 40)
        .frame(height: 112)
    }

    private var dictationSkeleton: some View {
        ScrollView {
            VStack(spacing: 18) {
                SkeletonBlock(height: 210, cornerRadius: 24)
                SkeletonBlock(
                    height: 92,
                    cornerRadius: TingXieControlMetrics.prominentCardCornerRadius
                )
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(
                            height: 96,
                            cornerRadius: TingXieControlMetrics.prominentCardCornerRadius
                        )
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBlock(width: 190, height: 20, cornerRadius: 6)
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonSetRow()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var vocabularySkeleton: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                SkeletonBlock(
                    height: TingXieControlMetrics.fieldHeight,
                    cornerRadius: TingXieControlMetrics.controlCornerRadius
                )
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 14) {
                        SkeletonBlock(
                            width: 56,
                            height: 56,
                            cornerRadius: TingXieControlMetrics.controlCornerRadius
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 118, height: 18, cornerRadius: 5)
                            SkeletonBlock(width: 170, height: 12, cornerRadius: 4)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        TingXiePalette.lightGreenSurface,
                        in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
                    )
                }
                Spacer()
            }
            .padding(20)
            .frame(minWidth: 390, idealWidth: 440)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 18) {
                    SkeletonBlock(width: 92, height: 92, cornerRadius: 20)
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBlock(width: 180, height: 30, cornerRadius: 7)
                        SkeletonBlock(width: 130, height: 15, cornerRadius: 5)
                    }
                }
                Divider()
                SkeletonBlock(width: 90, height: 17, cornerRadius: 5)
                SkeletonBlock(width: 280, height: 24, cornerRadius: 6)
                SkeletonBlock(width: 180, height: 17, cornerRadius: 5)
                SentenceCardSkeleton()
                SentenceCardSkeleton()
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var settingsSkeleton: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 11) {
                            SkeletonBlock(width: 22, height: 22, cornerRadius: 6)
                            SkeletonBlock(width: 130 + CGFloat(index * 12), height: 18, cornerRadius: 5)
                        }
                        Divider()
                        SkeletonBlock(height: 15, cornerRadius: 5)
                        SkeletonBlock(width: 360, height: 15, cornerRadius: 5)
                        SkeletonBlock(height: 40, cornerRadius: 10)
                    }
                    .padding(18)
                    .background(
                        TingXiePalette.lightGreenSurface,
                        in: RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
                    )
                }
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// Represents one set row without exposing placeholder text to assistive technologies.
private struct SkeletonSetRow: View {
    var body: some View {
        HStack(spacing: 18) {
            SkeletonBlock(width: 56, height: 56, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 9) {
                SkeletonBlock(width: 210, height: 18, cornerRadius: 5)
                SkeletonBlock(width: 150, height: 12, cornerRadius: 4)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                SkeletonBlock(width: 132, height: 8, cornerRadius: 4)
                SkeletonBlock(width: 72, height: 11, cornerRadius: 4)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 96)
        .background(
            TingXiePalette.lightGreenSurface,
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
        )
    }
}

// Replaces an indeterminate spinner with the shape of the flashcard being prepared.
struct PracticeCardSkeleton: View {
    var body: some View {
        VStack(spacing: 18) {
            SkeletonBlock(width: 260, height: 18, cornerRadius: 6)
            SkeletonBlock(width: 112, height: 112, cornerRadius: 56)
            SkeletonBlock(width: 190, height: 16, cornerRadius: 5)
        }
        .frame(width: 520, height: 330)
        .background(TingXiePalette.lightGreenSurface, in: RoundedRectangle(cornerRadius: 26))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preparing practice cards")
    }
}

// Preserves sentence-card geometry while Local AI generates both examples.
struct SentenceCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBlock(height: 17, cornerRadius: 5)
            SkeletonBlock(width: 260, height: 17, cornerRadius: 5)
            SkeletonBlock(height: 13, cornerRadius: 4)
            SkeletonBlock(width: 310, height: 13, cornerRadius: 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            TingXiePalette.lightGreenSurface,
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.cardCornerRadius)
        )
        .accessibilityHidden(true)
    }
}

// Shows editable-row geometry during dictionary lookup and optional AI fallback.
struct VocabularyDraftSkeleton: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(width: 120, height: 20, cornerRadius: 5)
                    HStack(spacing: 10) {
                        SkeletonBlock(height: 36, cornerRadius: 8)
                        SkeletonBlock(height: 36, cornerRadius: 8)
                    }
                }
                .padding(14)
                .background(
                    TingXiePalette.surfaceContainer.opacity(0.62),
                    in: RoundedRectangle(cornerRadius: TingXieControlMetrics.controlCornerRadius)
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filling vocabulary details")
    }
}

private extension AppSection {
    var accessibilityTitle: String {
        switch self {
        case .dictation: "Smart Dictation"
        case .vocabulary: "Vocabulary"
        case .settings: "Settings"
        }
    }
}

#Preview("Smart Dictation Skeleton") {
    WorkspaceSkeletonView(section: .dictation)
        .frame(width: 940, height: 720)
}

#Preview("Vocabulary Skeleton") {
    WorkspaceSkeletonView(section: .vocabulary)
        .frame(width: 940, height: 720)
}
