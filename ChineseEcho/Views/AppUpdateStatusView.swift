import SwiftUI

// Announces a newer release without interrupting practice; matches the Local AI status card.
struct AppUpdateStatusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    let update: AvailableAppUpdate
    let currentVersion: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(TingXiePalette.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 7) {
                Text("ChineseEcho \(update.version) Is Available")
                    .font(TingXieTypography.controlLabel)

                Text(
                    "You have \(currentVersion). Quit ChineseEcho, then replace it in "
                    + "Applications. Your library and settings stay in place."
                )
                .font(.system(size: 11))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("Download", systemImage: "arrow.down.circle.fill") {
                        openURL(update.downloadURL)
                    }
                    .buttonStyle(TingXieButtonStyle(size: .compact))

                    Button("What’s New") {
                        openURL(update.releaseNotesURL)
                    }
                    .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact))
                }
                .padding(.top, 2)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(TingXieButtonStyle(variant: .quiet, size: .compact, isIconOnly: true))
            .help("Remind Me Next Version")
            .accessibilityLabel("Dismiss update notice")
        }
        .padding(15)
        .frame(width: 360)
        .background(
            TingXiePalette.surfaceContainerHigh,
            in: RoundedRectangle(cornerRadius: TingXieControlMetrics.prominentCardCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: TingXieControlMetrics.prominentCardCornerRadius)
                .stroke(TingXiePalette.outlineVariant.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }
}

#Preview {
    AppUpdateStatusView(
        update: AvailableAppUpdate(
            version: "1.1",
            downloadURL: AppUpdateChecker.releasesPageURL,
            releaseNotesURL: AppUpdateChecker.releasesPageURL
        ),
        currentVersion: "1.0",
        onDismiss: {}
    )
    .padding(40)
    .background(TingXiePalette.background)
}
