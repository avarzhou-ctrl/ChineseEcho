import SwiftUI

enum TingXiePalette {
    static let sidebar = Color(red: 41 / 255, green: 97 / 255, blue: 36 / 255)
    static let sidebarSelection = Color(red: 114 / 255, green: 174 / 255, blue: 108 / 255).opacity(0.4)
    static let background = Color(red: 235 / 255, green: 255 / 255, blue: 230 / 255)
    static let workspace = background
    static let surface = Color(red: 236 / 255, green: 247 / 255, blue: 235 / 255)
    static let surfaceContainer = Color(red: 215 / 255, green: 246 / 255, blue: 211 / 255)
    static let surfaceContainerHigh = Color(red: 209 / 255, green: 241 / 255, blue: 206 / 255)
    static let surfaceContainerHighest = Color(red: 203 / 255, green: 235 / 255, blue: 200 / 255)
    static let accent = Color(red: 14 / 255, green: 73 / 255, blue: 14 / 255)
    static let secondary = Color(red: 45 / 255, green: 107 / 255, blue: 42 / 255)
    static let onBackground = Color(red: 7 / 255, green: 32 / 255, blue: 11 / 255)
    static let onSurfaceVariant = Color(red: 65 / 255, green: 73 / 255, blue: 62 / 255)
    static let outline = Color(red: 113 / 255, green: 121 / 255, blue: 109 / 255)
    static let outlineVariant = Color(red: 193 / 255, green: 201 / 255, blue: 186 / 255)
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
            sidebarHeader

            VStack(spacing: 8) {
                SidebarButton(
                    title: "Smart Dictation",
                    symbol: "waveform",
                    isSelected: selection == .dictation,
                    isCollapsed: isCollapsed,
                    action: onShowDictationHome
                )

                if let activeSet, !isCollapsed {
                    HStack(spacing: 8) {
                        Rectangle().frame(width: 2, height: 18)
                        Text(activeSet.title).lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.leading, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                SidebarButton(
                    title: "Your Vocabulary Hub",
                    symbol: "character.book.closed",
                    isSelected: selection == .vocabulary,
                    isCollapsed: isCollapsed
                ) {
                    selection = .vocabulary
                }

                SidebarButton(
                    title: "Settings",
                    symbol: "gearshape",
                    isSelected: selection == .settings,
                    isCollapsed: isCollapsed
                ) {
                    selection = .settings
                }
            }
            .padding(.horizontal, isCollapsed ? 8 : 16)
            .padding(.top, isCollapsed ? 28 : 18)

            Spacer()

            if !isCollapsed {
                WordOfDayCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomLeading)))
            }
        }
        .foregroundStyle(.white)
        .background(TingXiePalette.sidebar)
    }

    private var sidebarHeader: some View {
        ZStack(alignment: .topTrailing) {
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TingXieFlow")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                    Text("Audio-First Learning")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 52)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: onToggleCollapse) {
                Image(systemName: isCollapsed ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .help(isCollapsed ? "Expand Sidebar" : "Collapse Sidebar")
            .accessibilityLabel(isCollapsed ? "Expand Sidebar" : "Collapse Sidebar")
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }
}

private struct WordOfDayCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("WORD OF THE DAY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(TingXiePalette.wordOfDay)
            Text("把握")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("bǎ wò  ·  to grasp")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TingXiePalette.sidebarSelection, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Word of the day: 把握, bǎ wò, to grasp")
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
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24)
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : 16)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? TingXiePalette.sidebarSelection : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .help(title)
        .accessibilityLabel(title)
    }
}

struct WorkspaceHeader: View {
    let title: String
    var subtitle: String?
    var searchText: Binding<String>?
    var searchPrompt = "Search…"
    var showsAddButton = false
    var addAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(TingXiePalette.onBackground)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }
            }

            Spacer(minLength: 24)

            if let searchText {
                SearchField(text: searchText, prompt: searchPrompt)
                    .frame(width: 250)
            }

            if showsAddButton {
                Button(action: { addAction?() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(TingXiePalette.accent, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create New Set")
            }

            Image(systemName: "questionmark.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .accessibilityLabel("Help")
        }
        .padding(.horizontal, 40)
        .frame(height: 112)
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.65))
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .rounded))
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(TingXiePalette.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct GreenCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 40)
            .background(TingXiePalette.accent.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(Capsule())
            .shadow(color: TingXiePalette.accent.opacity(0.16), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OutlineCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(TingXiePalette.accent)
            .padding(.horizontal, 22)
            .frame(height: 40)
            .background(TingXiePalette.accent.opacity(configuration.isPressed ? 0.08 : 0.01))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(TingXiePalette.accent.opacity(0.25), lineWidth: 1) }
    }
}

struct TonalCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(TingXiePalette.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
    }
}

extension View {
    func tonalCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(TonalCardModifier(cornerRadius: cornerRadius))
    }
}

private struct TingXieColorPalettePreview: View {
    private let colors: [(name: String, value: String, color: Color)] = [
        ("Sidebar", "#296124", TingXiePalette.sidebar),
        ("Sidebar Selection", "#72AE6C · 40%", TingXiePalette.sidebarSelection),
        ("Background", "#EBFFE6", TingXiePalette.background),
        ("Workspace", "Background", TingXiePalette.workspace),
        ("Surface", "#ECF7EB", TingXiePalette.surface),
        ("Surface Container", "#D7F6D3", TingXiePalette.surfaceContainer),
        ("Surface Container High", "#D1F1CE", TingXiePalette.surfaceContainerHigh),
        ("Surface Container Highest", "#CBEBC8", TingXiePalette.surfaceContainerHighest),
        ("Accent", "#0E490E", TingXiePalette.accent),
        ("Secondary", "#2D6B2A", TingXiePalette.secondary),
        ("On Background", "#07200B", TingXiePalette.onBackground),
        ("On Surface Variant", "#41493E", TingXiePalette.onSurfaceVariant),
        ("Outline", "#71796D", TingXiePalette.outline),
        ("Outline Variant", "#C1C9BA", TingXiePalette.outlineVariant),
        ("Word of the Day", "#FDFBA7", TingXiePalette.wordOfDay),
        ("Missed", "#C41F23", TingXiePalette.missed),
        ("Table Stripe", "#A5C6A2 · 40%", TingXiePalette.tableStripe)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TingXieFlow Color Palette")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(TingXiePalette.onBackground)
                    Text("Named color tokens used across the app interface")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(colors, id: \.name) { sample in
                        VStack(alignment: .leading, spacing: 0) {
                            sample.color
                                .frame(height: 108)
                                .overlay(alignment: .bottomTrailing) {
                                    Text(sample.value)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(.black.opacity(0.48), in: Capsule())
                                        .padding(10)
                                }

                            Text(sample.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(TingXiePalette.onBackground)
                                .padding(14)
                        }
                        .background(Color.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TingXiePalette.outlineVariant.opacity(0.7), lineWidth: 1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(sample.name), \(sample.value)")
                    }
                }
            }
            .padding(32)
        }
        .background(TingXiePalette.background)
        .frame(width: 1000, height: 720)
    }
}

#Preview("TingXieFlow Color Palette") {
    TingXieColorPalettePreview()
}
