//
//  ContentView.swift
//  MandarinFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import AppKit
import SwiftData
import SwiftUI

// Coordinates app navigation, selected records, sidebar sizing, and set creation.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \DictationSet.dateCreated, order: .reverse) private var dictationSets: [DictationSet]
    @Query private var vocabularyWords: [VocabularyWord]

    @State private var selection: AppSection = .dictation
    @State private var sectionTransitionEdge: Edge = .trailing
    @State private var activeSetID: PersistentIdentifier?
    @State private var selectedVocabularyWordID: PersistentIdentifier?
    @State private var isCreatingSet = false
    @State private var isSidebarCollapsed = false
    @State private var modelDownloadCoordinator = ModelDownloadCoordinator.shared
    @State private var sidebarWidth =
        UserDefaults.standard.object(forKey: "sidebarWidth") as? Double ?? 266.0
    @AppStorage("sidebarWidth") private var persistedSidebarWidth = 266.0

    private let sidebarWidthRange = 220.0...420.0

    private var activeSet: DictationSet? {
        guard let activeSetID else { return nil }
        return dictationSets.first { $0.persistentModelID == activeSetID }
    }

    private var animatedSelection: Binding<AppSection> {
        Binding(
            get: { selection },
            set: updateSelection
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selection: animatedSelection,
                activeSet: activeSet,
                vocabularyWords: vocabularyWords,
                isCollapsed: isSidebarCollapsed,
                onToggleCollapse: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        isSidebarCollapsed.toggle()
                    }
                },
                onShowDictationHome: {
                    activeSetID = nil
                    updateSelection(.dictation)
                },
                onOpenWordOfDay: { word in
                    selectedVocabularyWordID = word.persistentModelID
                    updateSelection(.vocabulary)
                }
            )
            .frame(width: isSidebarCollapsed ? 64 : clampedSidebarWidth)

            SidebarResizeHandle(
                width: $sidebarWidth,
                allowedRange: sidebarWidthRange,
                isEnabled: !isSidebarCollapsed,
                onResizeEnded: { persistedSidebarWidth = $0 }
            )

            ZStack {
                Group {
                    switch selection {
                    case .dictation:
                        SmartDictationView(
                            sets: dictationSets,
                            activeSet: activeSet,
                            onCreateSet: { isCreatingSet = true },
                            onOpenVocabulary: { updateSelection(.vocabulary) },
                            onOpenSet: { activeSetID = $0.persistentModelID },
                            onCloseSet: { activeSetID = nil }
                        )
                    case .vocabulary:
                        VocabularyHubView(
                            words: vocabularyWords,
                            selectedWordID: $selectedVocabularyWordID
                        )
                    case .settings:
                        SettingsDashboard(
                            setCount: dictationSets.count,
                            wordCount: vocabularyWords.count
                        )
                    }
                }
                .id(selection)
                .transition(
                    TingXieMotion.directionalTransition(
                        enteringFrom: sectionTransitionEdge,
                        reduceMotion: reduceMotion
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(minWidth: 900, idealWidth: 1024, minHeight: 650, idealHeight: 768)
        .background(TingXiePalette.workspace)
        .overlay(alignment: .bottomTrailing) {
            if modelDownloadCoordinator.isStatusVisible {
                ModelDownloadStatusView(coordinator: modelDownloadCoordinator)
                    .padding(.trailing, 20)
                    .padding(.bottom, modelStatusBottomPadding)
            }
        }
        .animation(
            TingXieMotion.contentChange(reduceMotion: reduceMotion),
            value: modelDownloadCoordinator.isStatusVisible
        )
        .sheet(isPresented: $isCreatingSet) {
            NewDictationSetSheet(modelContainer: modelContext.container)
        }
        .task {
            await modelDownloadCoordinator.refreshCachedByteCount()
            modelDownloadCoordinator.startPreparing()
        }
    }

    private var clampedSidebarWidth: CGFloat {
        CGFloat(min(max(sidebarWidth, sidebarWidthRange.lowerBound), sidebarWidthRange.upperBound))
    }

    private var modelStatusBottomPadding: CGFloat {
        // The dictation home reserves 86 points for its floating action, plus a 16-point gap.
        selection == .dictation && activeSet == nil ? 102 : 20
    }

    private func updateSelection(_ newSelection: AppSection) {
        guard newSelection != selection else { return }
        let oldIndex = AppSection.allCases.firstIndex(of: selection) ?? 0
        let newIndex = AppSection.allCases.firstIndex(of: newSelection) ?? 0
        sectionTransitionEdge = newIndex > oldIndex ? .trailing : .leading
        withAnimation(TingXieMotion.filterSelection(reduceMotion: reduceMotion)) {
            selection = newSelection
        }
    }
}

// Enumerates the three top-level destinations controlled by the sidebar.
enum AppSection: Hashable, CaseIterable {
    case dictation
    case vocabulary
    case settings
}

// Adds a bounded, persistent drag target for resizing the custom sidebar.
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
