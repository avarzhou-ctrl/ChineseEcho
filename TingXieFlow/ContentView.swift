//
//  ContentView.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictationSet.dateCreated, order: .reverse) private var dictationSets: [DictationSet]
    @Query private var vocabularyWords: [VocabularyWord]

    @State private var selection: AppSection = .dictation
    @State private var activeSetID: PersistentIdentifier?
    @State private var selectedVocabularyWordID: PersistentIdentifier?
    @State private var isCreatingSet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var activeSet: DictationSet? {
        guard let activeSetID else { return nil }
        return dictationSets.first { $0.persistentModelID == activeSetID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebar(
                selection: $selection,
                activeSet: activeSet,
                vocabularyWords: vocabularyWords,
                onShowDictationHome: {
                    activeSetID = nil
                    selection = .dictation
                },
                onOpenWordOfDay: { word in
                    selectedVocabularyWordID = word.persistentModelID
                    selection = .vocabulary
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 266, max: 420)
        } detail: {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, idealWidth: 1024, minHeight: 650, idealHeight: 768)
        .background(TingXiePalette.workspace)
        .sheet(isPresented: $isCreatingSet) {
            NewDictationSetSheet { title, words in
                let store = DictationStore(modelContainer: modelContext.container)
                try await store.createSet(title: title, words: words)
            }
        }
    }
}

enum AppSection: Hashable {
    case dictation
    case vocabulary
    case settings
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, DictationSet.self, VocabularyWord.self], inMemory: true)
}
