//
//  CCCEDICTDictionary.swift
//  ChineseEcho
//

import Foundation

// Carries the concise dictionary data needed to populate a vocabulary draft.
struct CCCEDICTEntry: Sendable {
    let chinese: String
    let pinyin: String
    let translation: String
    let isIdiom: Bool
}

// Describes failures that prevent bundled dictionary lookup.
enum CCCEDICTError: LocalizedError {
    case resourceMissing

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "The bundled CC-CEDICT dictionary could not be found."
        }
    }
}

// Serializes dictionary loading, exact lookup, and result caching off the UI workflow.
actor CCCEDICTDictionary {
    static let shared = CCCEDICTDictionary()

    private let resourceURL: URL?
    private var dictionaryContents: String?
    private var cachedEntries: [String: CCCEDICTEntry] = [:]
    private var missingWords = Set<String>()

    init(resourceURL: URL? = nil) {
        self.resourceURL = resourceURL
    }

    func entries(for words: [String]) throws -> [String: CCCEDICTEntry] {
        let requestedWords = Set(words)
        let uncachedWords = requestedWords.filter {
            cachedEntries[$0] == nil && !missingWords.contains($0)
        }

        if !uncachedWords.isEmpty {
            try resolve(words: Set(uncachedWords))
        }

        return Dictionary(
            uniqueKeysWithValues: words.compactMap { word in
                cachedEntries[word].map { (word, $0) }
            }
        )
    }

    private func resolve(words: Set<String>) throws {
        guard let url = resourceURL ?? bundledResourceURL else {
            throw CCCEDICTError.resourceMissing
        }

        let contents: String
        if let dictionaryContents {
            contents = dictionaryContents
        } else {
            contents = try String(contentsOf: url, encoding: .utf8)
            dictionaryContents = contents
        }

        var parsed: [String: ScoredEntry] = [:]
        parsed.reserveCapacity(words.count)

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            guard !rawLine.hasPrefix("#"),
                  let headwords = Self.headwords(in: rawLine),
                  words.contains(headwords.simplified)
                    || words.contains(headwords.traditional),
                  let candidate = Self.parse(line: rawLine) else {
                continue
            }

            if words.contains(candidate.entry.chinese) {
                Self.store(candidate, for: candidate.entry.chinese, in: &parsed)
            }
            if words.contains(candidate.traditional) {
                Self.store(candidate, for: candidate.traditional, in: &parsed)
            }
        }

        for (word, candidate) in parsed {
            cachedEntries[word] = candidate.entry
        }
        missingWords.formUnion(words.subtracting(parsed.keys))
    }

    private var bundledResourceURL: URL? {
        Bundle.main.url(forResource: "cedict_ts", withExtension: "u8")
            ?? Bundle.main.url(
                forResource: "cedict_ts",
                withExtension: "u8",
                subdirectory: "Resources"
            )
    }

    private static func store(
        _ candidate: ScoredEntry,
        for word: String,
        in dictionary: inout [String: ScoredEntry]
    ) {
        if let current = dictionary[word], current.score > candidate.score {
            return
        }
        dictionary[word] = candidate
    }

    private static func parse(line: Substring) -> ScoredEntry? {
        guard let openingBracket = line.firstIndex(of: "["),
              let closingBracket = line[openingBracket...].firstIndex(of: "]") else {
            return nil
        }

        guard let headwords = headwords(in: line) else { return nil }
        let numberedPinyin = String(line[line.index(after: openingBracket)..<closingBracket])
        let definitions = line[line.index(after: closingBracket)...]
            .split(separator: "/")
            .map(String.init)

        guard let translation = preferredDefinition(from: definitions) else {
            return nil
        }

        let pinyin = PinyinToneConverter.convert(numberedPinyin)
        let conciseTranslation = compact(translation)
        guard !pinyin.isEmpty, !conciseTranslation.isEmpty else { return nil }
        let isIdiom = definitions.contains {
            $0.range(of: "(idiom)", options: .caseInsensitive) != nil
        }

        var score = definitionScore(translation)
        if numberedPinyin.first?.isLowercase == true {
            score += 4
        }

        return ScoredEntry(
            entry: CCCEDICTEntry(
                chinese: headwords.simplified,
                pinyin: pinyin,
                translation: conciseTranslation,
                isIdiom: isIdiom
            ),
            traditional: headwords.traditional,
            score: score
        )
    }

    private static func headwords(in line: Substring) -> (
        traditional: String,
        simplified: String
    )? {
        guard let openingBracket = line.firstIndex(of: "[") else { return nil }
        let values = line[..<openingBracket].split(whereSeparator: \.isWhitespace)
        guard values.count >= 2 else { return nil }
        return (String(values[0]), String(values[1]))
    }

    private static func preferredDefinition(from definitions: [String]) -> String? {
        definitions
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .max { definitionScore($0) < definitionScore($1) }
    }

    private static func definitionScore(_ definition: String) -> Int {
        let value = definition.lowercased()
        var score = 10

        if value.hasPrefix("cl:") { score -= 100 }
        if value.hasPrefix("variant of ") || value.hasPrefix("old variant of ") {
            score -= 60
        }
        if value.hasPrefix("see ") || value.hasPrefix("abbr. for ") {
            score -= 30
        }
        if value.hasPrefix("(") { score -= 2 }
        if value.hasPrefix("lit.") || value.hasPrefix("(lit.)") { score -= 8 }
        if value.contains("surname ") { score -= 8 }
        if value.count > 100 { score -= 2 }

        return score
    }

    private static func compact(_ definition: String) -> String {
        var value = definition.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("("), let closingParenthesis = value.firstIndex(of: ")") {
            value = String(value[value.index(after: closingParenthesis)...])
                .trimmingCharacters(in: .whitespaces)
        }
        if let separator = value.firstIndex(of: ";") {
            value = String(value[..<separator])
        }
        if let parenthesis = value.range(of: " (") {
            value = String(value[..<parenthesis.lowerBound])
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Keeps the best parsed definition when CC-CEDICT contains multiple entries for a word.
private struct ScoredEntry {
    let entry: CCCEDICTEntry
    let traditional: String
    let score: Int
}

// Converts numbered CC-CEDICT pinyin syllables into user-facing Unicode tone marks.
nonisolated private enum PinyinToneConverter {
    private static let toneMarks = [
        "",
        "\u{0304}",
        "\u{0301}",
        "\u{030C}",
        "\u{0300}"
    ]

    static func convert(_ numberedPinyin: String) -> String {
        numberedPinyin
            .split(whereSeparator: \.isWhitespace)
            .map { convertSyllable(String($0)) }
            .joined(separator: " ")
    }

    private static func convertSyllable(_ rawSyllable: String) -> String {
        var syllable = rawSyllable
            .lowercased()
            .replacingOccurrences(of: "u:", with: "ü")
            .replacingOccurrences(of: "v", with: "ü")

        guard let toneIndex = syllable.lastIndex(where: { $0.isNumber }),
              let tone = Int(String(syllable[toneIndex])),
              (1...5).contains(tone) else {
            return syllable
        }

        syllable.remove(at: toneIndex)
        guard tone < 5, let vowelIndex = markedVowelIndex(in: syllable) else {
            return syllable
        }

        let vowel = syllable[vowelIndex]
        syllable.replaceSubrange(
            vowelIndex...vowelIndex,
            with: String(vowel) + toneMarks[tone]
        )
        return syllable.precomposedStringWithCanonicalMapping
    }

    private static func markedVowelIndex(in syllable: String) -> String.Index? {
        if let index = syllable.firstIndex(of: "a") { return index }
        if let index = syllable.firstIndex(of: "e") { return index }
        if let range = syllable.range(of: "ou") { return range.lowerBound }
        return syllable.lastIndex { "aeiouü".contains($0) }
    }
}
