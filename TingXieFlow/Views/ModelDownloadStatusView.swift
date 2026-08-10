import SwiftUI

// Shows model setup progress without blocking navigation or dictionary-based learning.
struct ModelDownloadStatusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var coordinator: ModelDownloadCoordinator

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(coordinator.statusTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))

                    Spacer(minLength: 8)

                    if coordinator.phase == .downloading {
                        Text(coordinator.percentageText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(TingXiePalette.accent)
                    }
                }

                Text(coordinator.statusDetail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                    .lineLimit(2)

                if coordinator.phase == .downloading {
                    ProgressView(value: coordinator.fractionCompleted)
                        .progressViewStyle(.linear)
                        .tint(TingXiePalette.accent)
                        .accessibilityLabel("Local AI download progress")
                        .accessibilityValue(coordinator.percentageText)

                    Label(coordinator.predictedTimeText, systemImage: "clock")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .accessibilityLabel("Predicted Local AI download time")
                } else if coordinator.phase == .checking || coordinator.phase == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(coordinator.statusTitle)
                }
            }

            statusAction
        }
        .padding(15)
        .frame(width: 360)
        .background(TingXiePalette.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(TingXiePalette.outlineVariant.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var statusAction: some View {
        if coordinator.isPreparing {
            Button {
                Task { await coordinator.cancelPreparation() }
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Pause Download")
            .accessibilityLabel("Pause Local AI download")
        } else if coordinator.canRetry {
            Button(action: coordinator.startPreparing) {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Resume Download")
            .accessibilityLabel("Resume Local AI download")
        } else {
            Button(action: coordinator.hideStatus) {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss Local AI status")
        }
    }

    private var statusSymbol: String {
        switch coordinator.phase {
        case .idle: "arrow.down.circle"
        case .checking: "magnifyingglass"
        case .downloading: "arrow.down.circle.fill"
        case .loading: "cpu"
        case .ready: "checkmark.circle.fill"
        case .cancelled: "pause.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch coordinator.phase {
        case .ready: TingXiePalette.accent
        case .failed: TingXiePalette.missed
        default: TingXiePalette.secondary
        }
    }
}
