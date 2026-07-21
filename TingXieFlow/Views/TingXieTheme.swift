import SwiftUI

enum TingXiePalette {
    static let sidebar = Color(red: 41 / 255, green: 97 / 255, blue: 36 / 255)
    static let sidebarSelection = Color(red: 114 / 255, green: 174 / 255, blue: 108 / 255).opacity(0.4)
    static let workspace = Color(red: 186 / 255, green: 217 / 255, blue: 183 / 255)
    static let surface = Color(red: 236 / 255, green: 247 / 255, blue: 235 / 255)
    static let accent = Color(red: 39 / 255, green: 101 / 255, blue: 37 / 255)
    static let wordOfDay = Color(red: 253 / 255, green: 251 / 255, blue: 167 / 255)
    static let missed = Color(red: 196 / 255, green: 31 / 255, blue: 35 / 255)
}

struct AppSidebar: View {
    @Binding var selection: AppSection
    let activeSet: DictationSet?
    let onShowDictationHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TingXieFlow")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 45)
                .padding(.horizontal, 15)

            WordOfDayCard()
                .padding(.top, 10)
                .padding(.horizontal, 15)

            VStack(spacing: 8) {
                SidebarButton(
                    title: "Smart Dictation",
                    symbol: "waveform.badge.microphone",
                    isSelected: selection == .dictation
                ) {
                    onShowDictationHome()
                }

                if let activeSet {
                    HStack(spacing: 8) {
                        Rectangle()
                            .frame(width: 1, height: 20)
                        Text(activeSet.title)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SidebarButton(
                    title: "Your Vocabulary Hub",
                    symbol: "character.book.closed.fill",
                    isSelected: selection == .vocabulary
                ) {
                    selection = .vocabulary
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 16)

            Spacer()

            SidebarButton(
                title: "Settings",
                symbol: "gearshape.fill",
                isSelected: selection == .settings
            ) {
                selection = .settings
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
        .background(TingXiePalette.sidebar)
    }
}

private struct WordOfDayCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("上午")
                    .font(.system(size: 48, weight: .bold))
                Spacer()
                Image(systemName: "info.circle.fill")
                    .font(.title2)
            }

            Text("Morning")
                .font(.system(size: 30, weight: .medium))
            Text("WORD OF THE DAY")
                .font(.system(size: 16, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(TingXiePalette.wordOfDay)
        }
        .padding(10)
        .frame(height: 127)
        .background(TingXiePalette.sidebarSelection, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Word of the day: 上午, morning")
    }
}

private struct SidebarButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? TingXiePalette.sidebarSelection : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WorkspaceHeader: View {
    let title: String
    var showsAddButton = false
    var addAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(TingXiePalette.accent)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(TingXiePalette.accent)
                if showsAddButton {
                    Button(action: { addAction?() }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .font(.title2)
                    .foregroundStyle(TingXiePalette.accent)
                    .accessibilityLabel("Create New Set")
                }
            }
        }
        .padding(.top, 42)
        .padding(.horizontal, 40)
    }
}

struct GreenCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(TingXiePalette.accent.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
