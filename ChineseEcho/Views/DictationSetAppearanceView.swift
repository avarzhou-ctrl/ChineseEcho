import SwiftUI

// Resolves stored semantic color names into adaptive system-backed display colors.
extension DictationSetIconColor {
    var tint: Color {
        switch self {
        case .jade: TingXiePalette.accent
        case .teal: Color(nsColor: .systemTeal)
        case .blue: Color(nsColor: .systemBlue)
        case .indigo: Color(nsColor: .systemIndigo)
        case .orange: Color(nsColor: .systemOrange)
        case .rose: Color(nsColor: .systemPink)
        }
    }
}

// Renders the selected symbol or emoji with one consistent set-specific color treatment.
struct DictationSetIconBadge: View {
    let appearance: DictationSetAppearance
    var size: CGFloat = 52
    var cornerRadius: CGFloat = TingXieControlMetrics.cardCornerRadius

    var body: some View {
        Group {
            switch appearance.kind {
            case .symbol:
                Image(systemName: appearance.iconValue)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(appearance.color.tint)
            case .emoji:
                Text(appearance.iconValue)
                    .font(.system(size: size * 0.42))
            }
        }
        .frame(width: size, height: size)
        .background(appearance.color.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(appearance.color.tint.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appearance.accessibilityName)
        .accessibilityValue(appearance.color.accessibilityName)
    }
}

// Presents curated symbol, emoji, and color choices without accepting invalid persisted values.
struct DictationSetAppearancePicker: View {
    @Binding var selection: DictationSetAppearance
    @State private var selectedKind: DictationSetIconKind

    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6)

    init(selection: Binding<DictationSetAppearance>) {
        _selection = selection
        _selectedKind = State(initialValue: selection.wrappedValue.kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set Icon")
                .font(.system(size: 15, weight: .semibold))

            Picker("Icon type", selection: $selectedKind) {
                Text("Symbols").tag(DictationSetIconKind.symbol)
                Text("Emoji").tag(DictationSetIconKind.emoji)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DictationSetAppearanceCatalog.options(for: selectedKind)) { option in
                    iconButton(option)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Color")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 10) {
                    ForEach(DictationSetIconColor.allCases) { color in
                        colorButton(color)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 330)
        .onChange(of: selectedKind) { _, newKind in
            guard newKind != selection.kind,
                  let firstOption = DictationSetAppearanceCatalog.options(for: newKind).first else {
                return
            }
            selection = DictationSetAppearance(
                kind: newKind,
                iconValue: firstOption.value,
                color: selection.color
            )
        }
    }

    private func iconButton(_ option: DictationSetIconOption) -> some View {
        let isSelected = selection.kind == selectedKind && selection.iconValue == option.value
        return Button {
            selection = DictationSetAppearance(
                kind: selectedKind,
                iconValue: option.value,
                color: selection.color
            )
        } label: {
            Group {
                switch selectedKind {
                case .symbol:
                    Image(systemName: option.value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection.color.tint)
                case .emoji:
                    Text(option.value)
                        .font(.system(size: 18))
                }
            }
            .frame(width: 38, height: 38)
            .background(
                isSelected ? selection.color.tint.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: TingXieControlMetrics.compactCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TingXieControlMetrics.compactCornerRadius)
                    .stroke(
                        isSelected ? selection.color.tint : TingXiePalette.outlineVariant.opacity(0.65),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: TingXieControlMetrics.compactCornerRadius))
        }
        .buttonStyle(.plain)
        .help(option.accessibilityName)
        .accessibilityLabel(option.accessibilityName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func colorButton(_ color: DictationSetIconColor) -> some View {
        let isSelected = selection.color == color
        return Button {
            selection = DictationSetAppearance(
                kind: selection.kind,
                iconValue: selection.iconValue,
                color: color
            )
        } label: {
            ZStack {
                Circle()
                    .fill(color.tint)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .stroke(
                                isSelected ? TingXiePalette.onBackground : Color.clear,
                                lineWidth: 2
                            )
                    }
            }
            .frame(width: 38, height: 38)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(color.accessibilityName)
        .accessibilityLabel(color.accessibilityName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
