//
//  LLM.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/14.
//

import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

nonisolated private enum ModelDownloadError: LocalizedError {
    case invalidRepositoryID(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            return "Invalid Hugging Face repository ID: \(id)."
        }
    }
}

nonisolated private struct HuggingFaceDownloader: MLXLMCommon.Downloader {
    private let client = HuggingFace.HubClient()

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repositoryID = HuggingFace.Repo.ID(rawValue: id) else {
            throw ModelDownloadError.invalidRepositoryID(id)
        }

        return try await client.downloadSnapshot(
            of: repositoryID,
            revision: revision ?? "main",
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}

nonisolated private struct HuggingFaceTokenizer: MLXLMCommon.Tokenizer {
    private let tokenizer: any Tokenizers.Tokenizer

    init(_ tokenizer: any Tokenizers.Tokenizer) {
        self.tokenizer = tokenizer
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        tokenizer.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        tokenizer.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        tokenizer.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        tokenizer.convertIdToToken(id)
    }

    var bosToken: String? { tokenizer.bosToken }
    var eosToken: String? { tokenizer.eosToken }
    var unknownToken: String? { tokenizer.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try tokenizer.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

nonisolated private struct HuggingFaceTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return HuggingFaceTokenizer(tokenizer)
    }
}

actor LocalLanguageModel {
    static let shared = LocalLanguageModel()

    private var session: ChatSession?

    func generate(prompt: String) async throws -> String {
        let session = try await loadSession()
        let response = try await session.respond(to: prompt)
        return response.withoutThinkingBlock
    }

    private func loadSession() async throws -> ChatSession {
        if let session {
            return session
        }

        // The model is downloaded once and cached by the Hugging Face integration.
        let container = try await loadModelContainer(
            from: HuggingFaceDownloader(),
            using: HuggingFaceTokenizerLoader(),
            configuration: LLMRegistry.qwen3_0_6b_4bit
        )
        let session = ChatSession(
            container,
            additionalContext: ["enable_thinking": false]
        )
        self.session = session
        return session
    }
}

nonisolated private extension String {
    var withoutThinkingBlock: String {
        var output = self

        while let openingTag = output.range(of: "<think>", options: .caseInsensitive),
              let closingTag = output.range(
                of: "</think>",
                options: .caseInsensitive,
                range: openingTag.upperBound..<output.endIndex
              ) {
            output.removeSubrange(openingTag.lowerBound..<closingTag.upperBound)
        }

        // Some Qwen templates omit the opening tag from the decoded response.
        if let closingTag = output.range(
            of: "</think>",
            options: [.caseInsensitive, .backwards]
        ) {
            output.removeSubrange(output.startIndex..<closingTag.upperBound)
        }

        return output
            .replacingOccurrences(of: "<think>", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func generateText(prompt: String) async throws -> String {
    try await LocalLanguageModel.shared.generate(prompt: prompt)
}
