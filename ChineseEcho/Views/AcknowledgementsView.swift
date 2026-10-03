import SwiftUI

// Keeps required third-party notices available even when the Mac is offline.
struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    private let notices = BundledAcknowledgements.notices

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Acknowledgements & Licenses")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Open-source software, language data, and model notices")
                        .font(.system(size: 12))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(TingXieButtonStyle(size: .compact))
            }
            .padding(20)

            Divider()

            ScrollView {
                Text(notices)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .frame(minWidth: 680, minHeight: 560)
        .background(TingXiePalette.background)
    }
}

private enum BundledAcknowledgements {
    static let notices: String = {
        guard let url = Bundle.main.url(
            forResource: "THIRD-PARTY-NOTICES",
            withExtension: "txt"
        ) ?? Bundle.main.url(
            forResource: "THIRD-PARTY-NOTICES",
            withExtension: "txt",
            subdirectory: "Resources"
        ), let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return "Third-party notices could not be loaded. Visit avarzhou-ctrl.github.io/ChineseEcho/acknowledgements/ for the current notices."
        }
        return contents
    }()
}

#Preview {
    AcknowledgementsView()
}
