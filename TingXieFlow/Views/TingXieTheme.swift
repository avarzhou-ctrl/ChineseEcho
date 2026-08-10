import SwiftUI

// Applies the small offset and fade used by directional content replacement.
private struct TingXieDirectionalTransitionModifier: ViewModifier {
    let offset: CGSize
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset.width, y: offset.height)
            .opacity(opacity)
    }
}

// Centralizes adaptive colors shared by every TingXieFlow workspace and control.
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

// Centralizes short, restrained animations used when filters and collection content change.
enum TingXieMotion {
    static func filterSelection(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .snappy(duration: 0.28, extraBounce: 0.04)
    }

    static func contentChange(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.24)
    }

    static func directionalTransition(
        enteringFrom edge: Edge,
        reduceMotion: Bool
    ) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertionOffset = offset(for: edge)
        let removalOffset = offset(for: opposite(edge))
        return .asymmetric(
            insertion: .modifier(
                active: TingXieDirectionalTransitionModifier(
                    offset: insertionOffset,
                    opacity: 0
                ),
                identity: TingXieDirectionalTransitionModifier(offset: .zero, opacity: 1)
            ),
            removal: .modifier(
                active: TingXieDirectionalTransitionModifier(
                    offset: removalOffset,
                    opacity: 0
                ),
                identity: TingXieDirectionalTransitionModifier(offset: .zero, opacity: 1)
            )
        )
    }

    static func rowTransition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    static func inspectorTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.99))
    }

    private static func opposite(_ edge: Edge) -> Edge {
        return switch edge {
        case .top: .bottom
        case .leading: .trailing
        case .bottom: .top
        case .trailing: .leading
        }
    }

    private static func offset(for edge: Edge) -> CGSize {
        return switch edge {
        case .top: CGSize(width: 0, height: -16)
        case .leading: CGSize(width: -16, height: 0)
        case .bottom: CGSize(width: 0, height: 16)
        case .trailing: CGSize(width: 16, height: 0)
        }
    }
}

// Slides one shared selection surface between equal-width filter choices.
struct SlidingFilterBar<Item: Hashable & Identifiable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionAnimation

    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    let selectionShape: AnyShape
    let containerShape: AnyShape

    init(
        items: [Item],
        selection: Binding<Item>,
        selectionShape: AnyShape = AnyShape(Capsule()),
        containerShape: AnyShape = AnyShape(Capsule()),
        title: @escaping (Item) -> String
    ) {
        self.items = items
        _selection = selection
        self.title = title
        self.selectionShape = selectionShape
        self.containerShape = containerShape
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    guard selection != item else { return }
                    withAnimation(TingXieMotion.filterSelection(reduceMotion: reduceMotion)) {
                        selection = item
                    }
                } label: {
                    ZStack {
                        if selection == item {
                            selectionShape
                                .fill(Color.white)
                                .matchedGeometryEffect(
                                    id: "selected-filter",
                                    in: selectionAnimation
                                )
                        }

                        Text(title(item))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                selection == item
                                    ? TingXiePalette.accent
                                    : TingXiePalette.onSurfaceVariant
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(selectionShape)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(TingXiePalette.surfaceContainerHigh, in: containerShape)
    }
}

// Provides primary navigation, collapse behavior, and the daily vocabulary shortcut.
struct AppSidebar: View {
    @Binding var selection: AppSection
    let activeSet: DictationSet?
    let vocabularyWords: [VocabularyWord]
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onShowDictationHome: () -> Void
    let onOpenWordOfDay: (VocabularyWord) -> Void

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
                WordOfDayCard(words: vocabularyWords, onOpenWord: onOpenWordOfDay)
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

// Selects a deterministic daily word and exposes it as a sidebar shortcut.
private struct WordOfDayCard: View {
    let words: [VocabularyWord]
    let onOpenWord: (VocabularyWord) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3_600)) { context in
            let word = word(for: context.date)
            Button {
                if let word {
                    onOpenWord(word)
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("WORD OF THE DAY")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(TingXiePalette.wordOfDay)
                        Spacer()
                        if word != nil {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                    }

                    Text(word?.chinese ?? "开始")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(wordDetails(word))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(word == nil)
            .background(TingXiePalette.sidebarSelection, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .help(word == nil ? "Save vocabulary to receive a daily word." : "Open in Vocabulary Hub")
            .accessibilityLabel(accessibilityLabel(word))
        }
    }

    private func word(for date: Date) -> VocabularyWord? {
        let sortedWords = words.sorted {
            if $0.chinese == $1.chinese {
                return $0.pinyin.localizedStandardCompare($1.pinyin) == .orderedAscending
            }
            return $0.chinese.localizedStandardCompare($1.chinese) == .orderedAscending
        }
        guard !sortedWords.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return sortedWords[day % sortedWords.count]
    }

    private func wordDetails(_ word: VocabularyWord?) -> String {
        guard let word else { return "Save a word to begin" }
        let pinyin = word.pinyin.isEmpty ? "No pinyin" : word.pinyin
        let translation = word.englishTranslation.isEmpty ? "No translation yet" : word.englishTranslation
        return "\(pinyin)  ·  \(translation)"
    }

    private func accessibilityLabel(_ word: VocabularyWord?) -> String {
        guard let word else {
            return "Word of the day unavailable. Save vocabulary to begin."
        }
        return "Word of the day: \(word.chinese), \(wordDetails(word))"
    }
}

// Renders one expanded or icon-only navigation destination.
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

// Standardizes workspace titles, search, add actions, and contextual information.
struct WorkspaceHeader: View {
    let title: String
    var subtitle: String?
    var searchText: Binding<String>?
    var searchPrompt = "Search…"
    var searchAccessibilityLabel = "Search"
    var searchResults: AnyView?
    var searchResultsPresented: Binding<Bool>?
    var onSearchSubmit: (() -> Void)?
    var onMoveSearchSelection: ((Int) -> Void)?
    var showsAddButton = false
    var addAction: (() -> Void)?
    var info: WorkspaceInfo?

    @State private var isShowingInfo = false

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
                SearchField(
                    text: searchText,
                    prompt: searchPrompt,
                    accessibilityLabel: searchAccessibilityLabel,
                    results: searchResults,
                    resultsPresented: searchResultsPresented,
                    onSubmit: onSearchSubmit,
                    onMoveSelection: onMoveSearchSelection
                )
                    .frame(width: 250)
                    .zIndex(20)
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

            if info != nil {
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
                .help("About \(title)")
                .accessibilityLabel("About \(title)")
            }
        }
        .padding(.horizontal, 40)
        .frame(height: 112)
        .zIndex(20)
        .sheet(isPresented: $isShowingInfo) {
            if let info {
                WorkspaceInfoSheet(info: info)
            }
        }
    }
}

// Carries the copy and tips displayed by a workspace information sheet.
struct WorkspaceInfo: Sendable {
    let title: String
    let symbol: String
    let summary: String
    let tips: [String]
}

// Presents concise guidance without leaving the current workspace.
private struct WorkspaceInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let info: WorkspaceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: info.symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(TingXiePalette.accent)
                    .frame(width: 52, height: 52)
                    .background(TingXiePalette.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 5) {
                    Text(info.title)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(info.summary)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                        .lineSpacing(3)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(info.tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(TingXiePalette.accent, in: Circle())
                        Text(tip)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(TingXiePalette.onSurfaceVariant)
                            .lineSpacing(3)
                            .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(GreenCapsuleButtonStyle())
            }
        }
        .padding(28)
        .frame(width: 520, height: 390)
        .foregroundStyle(TingXiePalette.onBackground)
        .background(TingXiePalette.background)
    }
}

// Anchors live results to a reusable search input with keyboard navigation.
struct SearchField: View {
    @Binding var text: String
    let prompt: String
    var accessibilityLabel = "Search"
    var results: AnyView?
    var resultsPresented: Binding<Bool>?
    var onSubmit: (() -> Void)?
    var onMoveSelection: ((Int) -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.65))
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .rounded))
                .focused($isFocused)
                .onSubmit { onSubmit?() }
                .onKeyPress(.upArrow) {
                    onMoveSelection?(-1)
                    return onMoveSelection == nil ? .ignored : .handled
                }
                .onKeyPress(.downArrow) {
                    onMoveSelection?(1)
                    return onMoveSelection == nil ? .ignored : .handled
                }
                .onExitCommand {
                    if showsResults, !text.tingXieTrimmed.isEmpty {
                        resultsPresented?.wrappedValue = false
                    } else if !text.isEmpty {
                        text = ""
                    } else {
                        isFocused = false
                    }
                }
                .accessibilityLabel(accessibilityLabel)

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if !text.tingXieTrimmed.isEmpty {
                resultsPresented?.wrappedValue = true
            }
        }
        .background(TingXiePalette.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? TingXiePalette.accent.opacity(0.72) : TingXiePalette.outlineVariant.opacity(0.45),
                    lineWidth: isFocused ? 2 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if showsResults, !text.tingXieTrimmed.isEmpty, let results {
                results
                    .frame(width: 390)
                    .offset(y: 48)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: text.tingXieTrimmed.isEmpty)
        .background {
            Button("") {
                isFocused = true
                resultsPresented?.wrappedValue = true
            }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    private var showsResults: Bool {
        resultsPresented?.wrappedValue ?? true
    }
}

// Wraps arbitrary search results with a count header and clear action.
struct SearchResultsPanel<Content: View>: View {
    let resultCount: Int
    let emptyMessage: String
    let onClear: () -> Void
    let content: Content

    init(
        resultCount: Int,
        emptyMessage: String,
        onClear: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.resultCount = resultCount
        self.emptyMessage = emptyMessage
        self.onClear = onClear
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(resultCount == 1 ? "1 result" : "\(resultCount) results")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TingXiePalette.onSurfaceVariant)
                Spacer()
                Button("Clear", action: onClear)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TingXiePalette.accent)
                    .accessibilityLabel("Clear search")
            }
            .padding(.horizontal, 14)
            .frame(height: 38)

            Divider()
                .overlay(TingXiePalette.outlineVariant.opacity(0.55))

            if resultCount == 0 {
                VStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(TingXiePalette.secondary.opacity(0.55))
                    Text(emptyMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(TingXiePalette.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, minHeight: 112)
            } else {
                content
                    .frame(height: min(CGFloat(resultCount) * 62 + 12, 322))
            }
        }
        .background(TingXiePalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(TingXiePalette.outlineVariant.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: TingXiePalette.accent.opacity(0.12), radius: 14, y: 8)
    }
}

// Normalizes plain text and pinyin so searches ignore case, width, and tone marks.
enum SearchText {
    static func matches(_ value: String, query: String) -> Bool {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .localizedStandardContains(
                query.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            )
    }

    static func matchesPinyin(_ value: String, query: String) -> Bool {
        pinyinKey(value).contains(pinyinKey(query))
    }

    private static func pinyinKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "v", with: "u")
            .filter { $0.isLetter || $0.isNumber }
    }
}

extension String {
    var tingXieTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Styles primary actions with the app's accent-filled capsule treatment.
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

// Styles configurable secondary actions with a compact accent outline.
struct OutlineCapsuleButtonStyle: ButtonStyle {
    var fontSize: CGFloat = 15
    var horizontalPadding: CGFloat = 22
    var height: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(TingXiePalette.accent)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(TingXiePalette.accent.opacity(configuration.isPressed ? 0.08 : 0.01))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(TingXiePalette.accent.opacity(0.25), lineWidth: 1) }
    }
}

// Applies the shared translucent card surface and subtle outline.
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

// Visualizes palette tokens in Xcode without adding a runtime screen.
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
