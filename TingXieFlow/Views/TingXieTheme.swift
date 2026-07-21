import SwiftUI

enum TingXiePalette {
    static let sidebar = Color(red: 41 / 255, green: 97 / 255, blue: 36 / 255)
    static let sidebarSelection = Color(red: 114 / 255, green: 174 / 255, blue: 108 / 255).opacity(0.4)
    static let workspace = Color(red: 186 / 255, green: 217 / 255, blue: 183 / 255)
    static let surface = Color(red: 236 / 255, green: 247 / 255, blue: 235 / 255)
    static let accent = Color(red: 39 / 255, green: 101 / 255, blue: 37 / 255)
    static let wordOfDay = Color(red: 253 / 255, green: 251 / 255, blue: 167 / 255)
    static let missed = Color(red: 196 / 255, green: 31 / 255, blue: 35 / 255)
    static let tableStripe = Color(red: 165 / 255, green: 198 / 255, blue: 162 / 255).opacity(0.4)
}

struct AppSidebar: View {
    @Binding var selection: AppSection
    let activeSet: DictationSet?
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onShowDictationHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isCollapsed {
                Text("TingXieFlow")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 45)
                    .padding(.horizontal, 15)

                WordOfDayCard()
                    .padding(.top, 10)
                    .padding(.horizontal, 15)
            }

            VStack(spacing: 8) {
                SidebarButton(
                    title: "Smart Dictation",
                    symbol: "waveform.badge.microphone",
                    isSelected: selection == .dictation,
                    isCollapsed: isCollapsed
                ) {
                    onShowDictationHome()
                }

                if let activeSet, !isCollapsed {
                    HStack(spacing: 8) {
                        Rectangle()
                            .frame(width: 1, height: 20)
                        Text(activeSet.title)
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SidebarButton(
                    title: "Your Vocabulary Hub",
                    symbol: "character.book.closed.fill",
                    isSelected: selection == .vocabulary,
                    isCollapsed: isCollapsed
                ) {
                    selection = .vocabulary
                }
            }
            .padding(.horizontal, isCollapsed ? 6 : 15)
            .padding(.top, isCollapsed ? 58 : 16)

            Spacer()

            SidebarButton(
                title: "Settings",
                symbol: "gearshape.fill",
                isSelected: selection == .settings,
                isCollapsed: isCollapsed
            ) {
                selection = .settings
            }
            .padding(.horizontal, isCollapsed ? 6 : 15)
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
        .background(TingXiePalette.sidebar)
        .overlay(alignment: .topTrailing) {
            Button(action: onToggleCollapse) {
                Image(systemName: isCollapsed ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.top, 10)
            .padding(.trailing, isCollapsed ? 16 : 10)
            .help(isCollapsed ? "Expand Sidebar" : "Collapse Sidebar")
            .accessibilityLabel(isCollapsed ? "Expand Sidebar" : "Collapse Sidebar")
        }
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
                    .font(.system(size: 24))
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
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 22, height: 22)

                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, isCollapsed ? 15 : 16)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? TingXiePalette.sidebarSelection : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .help(title)
    }
}

struct WorkspaceHeader: View {
    let title: String
    var showsAddButton = false
    var addAction: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(title)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(TingXiePalette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 42)
                .padding(.horizontal, 40)

            VStack(spacing: 20) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(TingXiePalette.accent)
                if showsAddButton {
                    Button(action: { addAction?() }) {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(TingXiePalette.accent)
                    .accessibilityLabel("Create New Set")
                }
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
        }
        .frame(height: 112)
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
