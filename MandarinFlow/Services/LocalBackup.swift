import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// Defines the versioned, portable representation of the local learning library.
nonisolated struct MandarinFlowBackup: Codable, Sendable {
    nonisolated struct SetRecord: Codable, Sendable {
        let recordID: UUID
        let title: String
        let dateCreated: Date
        let words: [WordRecord]
    }

    nonisolated struct WordRecord: Codable, Sendable {
        let recordID: UUID
        let chinese: String
        let englishTranslation: String
        let pinyin: String
        let learnerHint: String?
        let isMissedWord: Bool
        let isIdiom: Bool
        let generatedSentence: String?
        let generatedBreakdown: String?
        let tags: [String]
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let createdAt: Date
    let sets: [SetRecord]
    let analytics: PracticeAnalyticsBackup
    let activeSession: SavedPracticeSession?

    var wordCount: Int { sets.reduce(0) { $0 + $1.words.count } }

    func validated() throws -> MandarinFlowBackup {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw LocalBackupError.unsupportedVersion(schemaVersion)
        }

        let setIDs = sets.map(\.recordID)
        guard Set(setIDs).count == setIDs.count else { throw LocalBackupError.duplicateSetID }
        guard sets.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw LocalBackupError.emptySetTitle
        }

        let words = sets.flatMap(\.words)
        let wordIDs = words.map(\.recordID)
        guard Set(wordIDs).count == wordIDs.count else { throw LocalBackupError.duplicateWordID }
        guard words.allSatisfy({
            !$0.chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.englishTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else { throw LocalBackupError.incompleteWord }

        if let activeSession {
            let sessionWordIDs = sets.first(where: {
                $0.recordID == activeSession.setRecordID
            }).map { Set($0.words.map(\.recordID)) } ?? []
            let queueWordIDs = Set(activeSession.queueWordRecordIDs)
            guard activeSession.version == SavedPracticeSession.currentVersion,
                  setIDs.contains(activeSession.setRecordID),
                  activeSession.currentIndex >= 0,
                  activeSession.currentIndex < activeSession.queueWordRecordIDs.count,
                  queueWordIDs.count == activeSession.queueWordRecordIDs.count,
                  queueWordIDs.isSubset(of: sessionWordIDs),
                  activeSession.grades.count <= activeSession.queueWordRecordIDs.count,
                  activeSession.grades.allSatisfy({ grade in
                      queueWordIDs.contains(grade.wordRecordID)
                          && activeSession.queueWordRecordIDs.indices.contains(grade.queueIndex)
                  })
            else { throw LocalBackupError.invalidPracticeSession }
        }

        for day in analytics.days.values {
            guard day.correctAttempts >= 0,
                  day.totalAttempts >= 0,
                  day.correctAttempts <= day.totalAttempts
            else { throw LocalBackupError.invalidLearningProgress }
        }
        return self
    }

    static func decode(_ data: Data) throws -> MandarinFlowBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(MandarinFlowBackup.self, from: data).validated()
        } catch let error as LocalBackupError {
            throw error
        } catch {
            throw LocalBackupError.unreadableFile
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

// Bridges the backup archive to SwiftUI's native save panel.
struct MandarinFlowBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let backup: MandarinFlowBackup

    init(backup: MandarinFlowBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw LocalBackupError.unreadableFile
        }
        backup = try MandarinFlowBackup.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try backup.encoded())
    }
}

// Fetches and replaces the complete SwiftData library inside a model actor.
@ModelActor
actor LocalBackupStore {
    func makeBackup(
        analytics: PracticeAnalyticsBackup,
        activeSession: SavedPracticeSession?
    ) throws -> MandarinFlowBackup {
        let sets = try modelContext.fetch(FetchDescriptor<DictationSet>())
            .sorted { $0.dateCreated < $1.dateCreated }
            .map { set in
                MandarinFlowBackup.SetRecord(
                    recordID: set.recordID,
                    title: set.title,
                    dateCreated: set.dateCreated,
                    words: set.vocabularyWords.map { word in
                        MandarinFlowBackup.WordRecord(
                            recordID: word.recordID,
                            chinese: word.chinese,
                            englishTranslation: word.englishTranslation,
                            pinyin: word.pinyin,
                            learnerHint: word.learnerHint,
                            isMissedWord: word.isMissedWord,
                            isIdiom: word.isIdiom,
                            generatedSentence: word.generatedSentence,
                            generatedBreakdown: word.generatedBreakdown,
                            tags: word.tags
                        )
                    }
                )
            }
        return MandarinFlowBackup(
            schemaVersion: MandarinFlowBackup.currentSchemaVersion,
            createdAt: Date(),
            sets: sets,
            analytics: analytics,
            activeSession: activeSession
        )
    }

    func replaceLibrary(with backup: MandarinFlowBackup) throws {
        let validated = try backup.validated()
        do {
            // Delete legacy orphans explicitly; owned words are removed by the set cascade.
            for word in try modelContext.fetch(FetchDescriptor<VocabularyWord>()) where word.session == nil {
                modelContext.delete(word)
            }
            for set in try modelContext.fetch(FetchDescriptor<DictationSet>()) {
                modelContext.delete(set)
            }

            for savedSet in validated.sets {
                let set = DictationSet(
                    recordID: savedSet.recordID,
                    title: savedSet.title,
                    dateCreated: savedSet.dateCreated
                )
                modelContext.insert(set)
                for savedWord in savedSet.words {
                    let word = VocabularyWord(
                        recordID: savedWord.recordID,
                        chinese: savedWord.chinese,
                        englishTranslation: savedWord.englishTranslation,
                        pinyin: savedWord.pinyin,
                        learnerHint: savedWord.learnerHint,
                        isMissedWord: savedWord.isMissedWord,
                        isIdiom: savedWord.isIdiom,
                        tags: savedWord.tags
                    )
                    word.generatedSentence = savedWord.generatedSentence
                    word.generatedBreakdown = savedWord.generatedBreakdown
                    word.session = set
                    set.vocabularyWords.append(word)
                    modelContext.insert(word)
                }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

// Gives malformed or incompatible backup files actionable user-facing errors.
nonisolated enum LocalBackupError: LocalizedError {
    case unreadableFile
    case unsupportedVersion(Int)
    case duplicateSetID
    case duplicateWordID
    case emptySetTitle
    case incompleteWord
    case invalidLearningProgress
    case invalidPracticeSession

    var errorDescription: String? {
        switch self {
        case .unreadableFile: "This file is not a valid MandarinFlow backup."
        case .unsupportedVersion(let version): "Backup version \(version) is not supported by this version of MandarinFlow."
        case .duplicateSetID: "The backup contains duplicate set identifiers."
        case .duplicateWordID: "The backup contains duplicate vocabulary identifiers."
        case .emptySetTitle: "Every restored set must have a name."
        case .incompleteWord: "Every restored word must include Chinese, pinyin, and an English meaning."
        case .invalidLearningProgress: "The backup contains invalid learning progress."
        case .invalidPracticeSession: "The backup contains an invalid interrupted practice session."
        }
    }
}
