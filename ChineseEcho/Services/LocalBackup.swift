import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// Defines the versioned, portable representation of the local learning library.
nonisolated struct ChineseEchoBackup: Codable, Sendable {
    nonisolated struct SetRecord: Codable, Sendable {
        nonisolated struct AppearanceRecord: Codable, Sendable {
            let kind: String
            let iconValue: String
            let color: String

            init(_ appearance: DictationSetAppearance) {
                kind = appearance.kind.rawValue
                iconValue = appearance.iconValue
                color = appearance.color.rawValue
            }

            var value: DictationSetAppearance {
                DictationSetAppearance(
                    kindRawValue: kind,
                    iconValue: iconValue,
                    colorRawValue: color
                )
            }
        }

        let recordID: UUID
        let title: String
        let dateCreated: Date
        let appearance: AppearanceRecord?
        let cardLayout: String?
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
        let reviewBox: Int?
        let lastReviewedAt: Date?
        let nextReviewAt: Date?
        let generatedSentence: String?
        let generatedBreakdown: String?
        let tags: [String]
    }

    static let currentSchemaVersion = 4
    static let supportedSchemaVersions = 1...currentSchemaVersion

    let schemaVersion: Int
    let createdAt: Date
    let sets: [SetRecord]
    let analytics: PracticeAnalyticsBackup
    let activeSession: SavedPracticeSession?
    let reviewSchedulePreferences: ReviewSchedulePreferenceSnapshot?

    var wordCount: Int { sets.reduce(0) { $0 + $1.words.count } }

    func validated() throws -> ChineseEchoBackup {
        guard Self.supportedSchemaVersions.contains(schemaVersion) else {
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
            let allWordIDs = Set(words.map(\.recordID))
            let sessionWordIDs: Set<UUID>
            switch activeSession.resolvedSourceKind {
            case .set:
                guard let setRecordID = activeSession.setRecordID,
                      setIDs.contains(setRecordID)
                else { throw LocalBackupError.invalidPracticeSession }
                sessionWordIDs = sets.first(where: {
                    $0.recordID == setRecordID
                }).map { Set($0.words.map(\.recordID)) } ?? []
            case .dueReview:
                sessionWordIDs = allWordIDs
            }
            let queueWordIDs = Set(activeSession.queueWordRecordIDs)
            guard SavedPracticeSession.supportedVersions.contains(activeSession.version),
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
        for word in words {
            guard word.reviewBox.map({ (1...ReviewScheduler.maximumBox).contains($0) }) ?? true,
                  (word.reviewBox == nil) == (word.nextReviewAt == nil),
                  (word.reviewBox == nil) == (word.lastReviewedAt == nil)
            else { throw LocalBackupError.invalidLearningProgress }
        }
        if let reviewSchedulePreferences,
           !reviewSchedulePreferences.customConfiguration.isValid {
            throw LocalBackupError.invalidReviewSchedule
        }
        return self
    }

    static func decode(_ data: Data) throws -> ChineseEchoBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(ChineseEchoBackup.self, from: data).validated()
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
struct ChineseEchoBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let backup: ChineseEchoBackup

    init(backup: ChineseEchoBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw LocalBackupError.unreadableFile
        }
        backup = try ChineseEchoBackup.decode(data)
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
        activeSession: SavedPracticeSession?,
        reviewSchedulePreferences: ReviewSchedulePreferenceSnapshot
    ) throws -> ChineseEchoBackup {
        let sets = try modelContext.fetch(FetchDescriptor<DictationSet>())
            .sorted { $0.dateCreated < $1.dateCreated }
            .map { set in
                ChineseEchoBackup.SetRecord(
                    recordID: set.recordID,
                    title: set.title,
                    dateCreated: set.dateCreated,
                    appearance: ChineseEchoBackup.SetRecord.AppearanceRecord(set.appearance),
                    cardLayout: set.cardLayout.rawValue,
                    words: set.vocabularyWords.map { word in
                        ChineseEchoBackup.WordRecord(
                            recordID: word.recordID,
                            chinese: word.chinese,
                            englishTranslation: word.englishTranslation,
                            pinyin: word.pinyin,
                            learnerHint: word.learnerHint,
                            isMissedWord: word.isMissedWord,
                            isIdiom: word.isIdiom,
                            reviewBox: word.reviewBox,
                            lastReviewedAt: word.lastReviewedAt,
                            nextReviewAt: word.nextReviewAt,
                            generatedSentence: word.generatedSentence,
                            generatedBreakdown: word.generatedBreakdown,
                            tags: word.tags
                        )
                    }
                )
            }
        return ChineseEchoBackup(
            schemaVersion: ChineseEchoBackup.currentSchemaVersion,
            createdAt: Date(),
            sets: sets,
            analytics: analytics,
            activeSession: activeSession,
            reviewSchedulePreferences: reviewSchedulePreferences
        )
    }

    func replaceLibrary(with backup: ChineseEchoBackup) throws {
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
                    dateCreated: savedSet.dateCreated,
                    appearance: savedSet.appearance?.value ?? .defaultValue,
                    cardLayout: savedSet.cardLayout.flatMap(VocabularyCardLayout.init(rawValue:))
                        ?? AppPreferenceDefault.vocabularyCardLayout
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
                        reviewBox: savedWord.reviewBox,
                        lastReviewedAt: savedWord.lastReviewedAt,
                        nextReviewAt: savedWord.nextReviewAt,
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
    case invalidReviewSchedule

    var errorDescription: String? {
        switch self {
        case .unreadableFile: "This file is not a valid ChineseEcho backup."
        case .unsupportedVersion(let version): "Backup version \(version) is not supported by this version of ChineseEcho."
        case .duplicateSetID: "The backup contains duplicate set identifiers."
        case .duplicateWordID: "The backup contains duplicate vocabulary identifiers."
        case .emptySetTitle: "Every restored set must have a name."
        case .incompleteWord: "Every restored word must include Chinese, pinyin, and an English meaning."
        case .invalidLearningProgress: "The backup contains invalid learning progress."
        case .invalidPracticeSession: "The backup contains an invalid interrupted practice session."
        case .invalidReviewSchedule: "The backup contains an invalid custom review schedule."
        }
    }
}
