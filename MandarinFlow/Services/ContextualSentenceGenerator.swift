import Foundation
import SwiftData

// Carries the minimum saved-word data needed for automatic contextual enrichment.
nonisolated struct ContextualSentenceGenerationTarget: Sendable {
    let wordRecordID: UUID
    let chinese: String
    let englishTranslation: String
}

// Generates and validates the bilingual examples shared by automatic and manual enrichment.
@MainActor
enum ContextualSentenceGenerator {
    static func generateStoredSentence(
        chinese: String,
        englishTranslation: String
    ) async throws -> String {
        let response = try await generateText(
            prompt: generationPrompt(
                chinese: chinese,
                englishTranslation: englishTranslation
            )
        )
        let payload: ContextualSentencePayload
        do {
            payload = try ContextualSentencePayload.parse(
                response,
                vocabulary: chinese
            )
        } catch ContextualSentenceError.invalidResponse {
            let repairedResponse = try await generateText(
                prompt: repairPrompt(response, vocabulary: chinese)
            )
            payload = try ContextualSentencePayload.parse(
                repairedResponse,
                vocabulary: chinese
            )
        }
        return try payload.encoded()
    }

    static func generateAndStore(
        targets: [ContextualSentenceGenerationTarget],
        modelContainer: ModelContainer
    ) async {
        guard !targets.isEmpty else { return }
        let store = DictationStore(modelContainer: modelContainer)

        for target in targets {
            do {
                let sentence = try await generateStoredSentence(
                    chinese: target.chinese,
                    englishTranslation: target.englishTranslation
                )
                try await store.setGeneratedSentence(
                    sentence,
                    wordRecordID: target.wordRecordID
                )
            } catch {
                // A failed background enrichment leaves the manual Generate action available.
                continue
            }
        }
    }

    private static func generationPrompt(
        chinese: String,
        englishTranslation: String
    ) -> String {
        """
        请用词语“\(chinese)”（英文含义：\(englishTranslation)）写两个不同的现代中文例句，并为每句提供自然、简洁的英文翻译。每个中文例句都必须自然包含完全相同的词语“\(chinese)”，并严格遵守系统提供的例句质量要求。英文翻译必须完整翻译该词语，不能保留任何中文字符。每个 englishVocabulary 字段必须逐字复制该英文翻译中对应“\(chinese)”的英文词语或短语，包括实际使用的词形。

        只输出以下 JSON，不要使用 Markdown 或添加其他文字：
        {"examples":[{"chinese":"第一个中文例句","english":"First English translation.","englishVocabulary":"translated term"},{"chinese":"第二个中文例句","english":"Second English translation.","englishVocabulary":"translated term"}]}
        """
    }

    private static func repairPrompt(
        _ candidate: String,
        vocabulary: String
    ) -> String {
        """
        Repair the candidate output into exactly two complete bilingual examples for the Chinese vocabulary word “\(vocabulary)”. Each Chinese sentence must naturally contain the exact word “\(vocabulary)”. Each English field must be a complete, natural English translation of its Chinese sentence and must not contain any Chinese characters. Translate the vocabulary word instead of copying it into the English field. Each englishVocabulary field must copy the exact English word or phrase used to translate “\(vocabulary)” in that example's English sentence, including its actual inflection.

        Return only valid JSON in this exact shape, with no Markdown or commentary:
        {"examples":[{"chinese":"第一个中文例句","english":"First English translation.","englishVocabulary":"translated term"},{"chinese":"第二个中文例句","english":"Second English translation.","englishVocabulary":"translated term"}]}

        <candidate_output>
        \(candidate)
        </candidate_output>
        """
    }
}

// Stores bilingual examples inside the existing sentence field without a SwiftData migration.
nonisolated struct ContextualSentencePayload: Codable {
    let examples: [ContextualSentence]

    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let value = String(data: data, encoding: .utf8) else {
            throw ContextualSentenceError.invalidResponse
        }
        return value
    }

    static func parse(_ response: String, vocabulary: String) throws -> Self {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let openingBrace = trimmed.firstIndex(of: "{"),
              let closingBrace = trimmed.lastIndex(of: "}") else {
            throw ContextualSentenceError.invalidResponse
        }

        let json = String(trimmed[openingBrace...closingBrace])
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Self.self, from: data),
              payload.examples.count == 2,
              payload.examples.allSatisfy({
                  !$0.chinese.isEmpty
                      && !$0.english.isEmpty
                      && $0.chinese.contains(vocabulary)
                      && !containsHan($0.english)
                      && !($0.englishVocabulary ?? "").isEmpty
                      && $0.english.localizedCaseInsensitiveContains(
                          $0.englishVocabulary ?? ""
                      )
              }) else {
            throw ContextualSentenceError.invalidResponse
        }
        return payload
    }

    static func storedExamples(from value: String?) -> [ContextualSentence] {
        guard let value, !value.isEmpty else { return [] }
        if let data = value.data(using: .utf8),
           let payload = try? JSONDecoder().decode(Self.self, from: data) {
            guard payload.examples.allSatisfy({ !containsHan($0.english) }) else { return [] }
            return payload.examples
        }

        // Keep sentences generated by earlier app versions visible after this UI update.
        return [ContextualSentence(chinese: value, english: "", englishVocabulary: nil)]
    }

    private static func containsHan(_ text: String) -> Bool {
        text.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}

nonisolated struct ContextualSentence: Codable, Identifiable {
    var id: String { chinese + english }
    let chinese: String
    let english: String
    let englishVocabulary: String?
}

nonisolated enum ContextualSentenceError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "Local AI did not return two complete bilingual examples. Please try again."
    }
}
