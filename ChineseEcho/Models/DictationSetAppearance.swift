import Foundation

// Describes the two native visual treatments available for a dictation set.
nonisolated enum DictationSetIconKind: String, Codable, CaseIterable, Sendable {
    case symbol
    case emoji
}

// Stores a stable semantic color name instead of archiving display-specific color values.
nonisolated enum DictationSetIconColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case jade
    case teal
    case blue
    case indigo
    case orange
    case rose

    var id: String { rawValue }

    var accessibilityName: String {
        switch self {
        case .jade: "Jade"
        case .teal: "Teal"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .orange: "Orange"
        case .rose: "Rose"
        }
    }
}

// Provides one curated icon choice with a stable value and a spoken label.
nonisolated struct DictationSetIconOption: Identifiable, Hashable, Sendable {
    let value: String
    let accessibilityName: String

    var id: String { value }
}

// Keeps selectable symbols and emoji valid across persistence, backup, and UI rendering.
nonisolated enum DictationSetAppearanceCatalog {
    static let symbols = [
        DictationSetIconOption(value: "character.book.closed.fill", accessibilityName: "Vocabulary book"),
        DictationSetIconOption(value: "graduationcap.fill", accessibilityName: "Graduation cap"),
        DictationSetIconOption(value: "airplane", accessibilityName: "Travel"),
        DictationSetIconOption(value: "fork.knife", accessibilityName: "Food"),
        DictationSetIconOption(value: "bubble.left.and.bubble.right.fill", accessibilityName: "Conversation"),
        DictationSetIconOption(value: "figure.walk", accessibilityName: "Daily life"),
        DictationSetIconOption(value: "house.fill", accessibilityName: "Home"),
        DictationSetIconOption(value: "cart.fill", accessibilityName: "Shopping"),
        DictationSetIconOption(value: "briefcase.fill", accessibilityName: "Work"),
        DictationSetIconOption(value: "music.note", accessibilityName: "Music"),
        DictationSetIconOption(value: "leaf.fill", accessibilityName: "Nature"),
        DictationSetIconOption(value: "star.fill", accessibilityName: "Favorites")
    ]

    static let emoji = [
        DictationSetIconOption(value: "📚", accessibilityName: "Books"),
        DictationSetIconOption(value: "🎓", accessibilityName: "Graduation cap"),
        DictationSetIconOption(value: "✈️", accessibilityName: "Airplane"),
        DictationSetIconOption(value: "🍜", accessibilityName: "Noodles"),
        DictationSetIconOption(value: "💬", accessibilityName: "Conversation"),
        DictationSetIconOption(value: "🚶", accessibilityName: "Walking"),
        DictationSetIconOption(value: "🏠", accessibilityName: "Home"),
        DictationSetIconOption(value: "🛍️", accessibilityName: "Shopping"),
        DictationSetIconOption(value: "💼", accessibilityName: "Work"),
        DictationSetIconOption(value: "🎵", accessibilityName: "Music"),
        DictationSetIconOption(value: "🌿", accessibilityName: "Nature"),
        DictationSetIconOption(value: "⭐️", accessibilityName: "Favorite")
    ]

    static func options(for kind: DictationSetIconKind) -> [DictationSetIconOption] {
        switch kind {
        case .symbol: symbols
        case .emoji: emoji
        }
    }
}

// Carries a validated set appearance across model-actor and backup boundaries.
nonisolated struct DictationSetAppearance: Equatable, Sendable {
    static let defaultValue = DictationSetAppearance(
        kind: .symbol,
        iconValue: "character.book.closed.fill",
        color: .jade
    )

    let kind: DictationSetIconKind
    let iconValue: String
    let color: DictationSetIconColor

    init(
        kind: DictationSetIconKind,
        iconValue: String,
        color: DictationSetIconColor
    ) {
        let options = DictationSetAppearanceCatalog.options(for: kind)
        if options.contains(where: { $0.value == iconValue }) {
            self.kind = kind
            self.iconValue = iconValue
        } else {
            self.kind = Self.defaultValue.kind
            self.iconValue = Self.defaultValue.iconValue
        }
        self.color = color
    }

    init(kindRawValue: String?, iconValue: String?, colorRawValue: String?) {
        guard let kindRawValue,
              let kind = DictationSetIconKind(rawValue: kindRawValue),
              let iconValue,
              let colorRawValue,
              let color = DictationSetIconColor(rawValue: colorRawValue) else {
            self = .defaultValue
            return
        }
        self.init(kind: kind, iconValue: iconValue, color: color)
    }

    var accessibilityName: String {
        DictationSetAppearanceCatalog.options(for: kind)
            .first(where: { $0.value == iconValue })?
            .accessibilityName ?? "Set icon"
    }
}
