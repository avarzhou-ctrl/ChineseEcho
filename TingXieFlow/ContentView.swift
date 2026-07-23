//
//  ContentView.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import AppKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictationSet.dateCreated, order: .reverse) private var dictationSets: [DictationSet]
    @Query private var vocabularyWords: [VocabularyWord]

    @State private var selection: AppSection = .dictation
    @State private var activeSetID: PersistentIdentifier?
    @State private var isCreatingSet = false
    @State private var isSidebarCollapsed = false
    @State private var sidebarWidth =
        UserDefaults.standard.object(forKey: "sidebarWidth") as? Double ?? 266.0
    @AppStorage("sidebarWidth") private var persistedSidebarWidth = 266.0

    private let sidebarWidthRange = 220.0...420.0

    private var activeSet: DictationSet? {
        guard let activeSetID else { return nil }
        return dictationSets.first { $0.persistentModelID == activeSetID }
    }

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selection: $selection,
                activeSet: activeSet,
                isCollapsed: isSidebarCollapsed,
                onToggleCollapse: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        isSidebarCollapsed.toggle()
                    }
                }
            ) {
                activeSetID = nil
                selection = .dictation
            }
            .frame(width: isSidebarCollapsed ? 64 : clampedSidebarWidth)

            SidebarResizeHandle(
                width: $sidebarWidth,
                allowedRange: sidebarWidthRange,
                isEnabled: !isSidebarCollapsed,
                onResizeEnded: { persistedSidebarWidth = $0 }
            )

            Group {
                switch selection {
                case .dictation:
                    SmartDictationView(
                        sets: dictationSets,
                        activeSet: activeSet,
                        onCreateSet: { isCreatingSet = true },
                        onOpenVocabulary: { selection = .vocabulary },
                        onOpenSet: { activeSetID = $0.persistentModelID },
                        onCloseSet: { activeSetID = nil }
                    )
                case .vocabulary:
                    VocabularyHubView(words: vocabularyWords)
                case .settings:
                    SettingsDashboard()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, idealWidth: 1024, minHeight: 650, idealHeight: 768)
        .background(TingXiePalette.workspace)
        .sheet(isPresented: $isCreatingSet) {
            NewDictationSetSheet { title, words in
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.createSet(title: title, words: words)
            }
        }
    }

    private var clampedSidebarWidth: CGFloat {
        CGFloat(min(max(sidebarWidth, sidebarWidthRange.lowerBound), sidebarWidthRange.upperBound))
    }
}

enum AppSection: Hashable {
    case dictation
    case vocabulary
    case settings
}

private struct SidebarResizeHandle: View {
    @Binding var width: Double
    let allowedRange: ClosedRange<Double>
    let isEnabled: Bool
    let onResizeEnded: (Double) -> Void

    @State private var dragStartWidth: Double?

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: isEnabled ? 8 : 1)
            .overlay {
                Rectangle()
                    .fill(TingXiePalette.outline.opacity(0.35))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering && isEnabled {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled {
                    NSCursor.arrow.set()
                }
            }
            .onDisappear {
                NSCursor.arrow.set()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if dragStartWidth == nil {
                            dragStartWidth = width
                        }
                        let proposedWidth = (dragStartWidth ?? width) + Double(value.translation.width)
                        width = min(
                            max(proposedWidth, allowedRange.lowerBound),
                            allowedRange.upperBound
                        )
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                        onResizeEnded(width)
                    }
            )
            .accessibilityElement()
            .accessibilityHidden(!isEnabled)
            .accessibilityLabel("Resize sidebar")
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                let adjustment = direction == .increment ? 20.0 : -20.0
                width = min(
                    max(width + adjustment, allowedRange.lowerBound),
                    allowedRange.upperBound
                )
                onResizeEnded(width)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, DictationSet.self, VocabularyWord.self], inMemory: true)
}
