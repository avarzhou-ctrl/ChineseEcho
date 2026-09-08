//
//  LLMTestView.swift
//  ChineseEcho
//
//  Created by Ava Zhou on 2026/7/20.
//

import SwiftUI

// Provides a developer scratchpad for sending prompts to the bundled local model.
struct LLMTestView: View {
    @State private var prompt = "请用错词“坚持”写一个自然、简短的现代中文句子。"
    @State private var response = ""
    @State private var errorMessage: String?
    @State private var isGenerating = false
    @State private var generationTask: Task<Void, Never>?
    @State private var modelDownloadCoordinator = ModelDownloadCoordinator.shared

    private let modelName = "\(LocalModelSpec.displayName) · MLX"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            promptEditor
            actionBar
            resultPanel
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 520)
        .foregroundStyle(TingXiePalette.onBackground)
        .tint(TingXiePalette.accent)
        .background(TingXiePalette.background)
        .navigationTitle("LLM Test")
        .onDisappear {
            generationTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Local LLM Playground", systemImage: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(TingXiePalette.accent)

            Text("Run a prompt locally with \(modelName). The model downloads once on first use.")
                .font(TingXieTypography.body)
                .foregroundStyle(TingXiePalette.onSurfaceVariant)
        }
    }

    private var promptEditor: some View {
        GroupBox {
            TextEditor(text: $prompt)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.vertical, 8)
                .tingXieInputSurface(minimumHeight: 120)
        } label: {
            Label("Prompt", systemImage: "text.cursor")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: generate) {
                if modelDownloadCoordinator.phase == .downloading {
                    Label(
                        "Downloading \(modelDownloadCoordinator.percentageText)",
                        systemImage: "arrow.down.circle.fill"
                    )
                } else if modelDownloadCoordinator.isPreparing {
                    Label("Preparing AI…", systemImage: "cpu")
                } else {
                    Label(isGenerating ? "Generating…" : "Generate", systemImage: "paperplane.fill")
                }
            }
            .buttonStyle(TingXieButtonStyle())
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(trimmedPrompt.isEmpty || isGenerating || modelDownloadCoordinator.isPreparing)

            if isGenerating || modelDownloadCoordinator.isPreparing {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Text(modelName)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var resultPanel: some View {
        GroupBox {
            ScrollView {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if response.isEmpty {
                    ContentUnavailableView(
                        "No Response Yet",
                        systemImage: "text.bubble",
                        description: Text("Enter a prompt and choose Generate.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    Text(response)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 170, maxHeight: .infinity)
        } label: {
            Label("Response", systemImage: "bubble.left.and.text.bubble.right")
        }
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generate() {
        let submittedPrompt = trimmedPrompt
        guard !submittedPrompt.isEmpty else { return }

        generationTask?.cancel()
        isGenerating = true
        errorMessage = nil
        response = ""

        generationTask = Task {
            defer { isGenerating = false }

            do {
                let generatedText = try await generateText(prompt: submittedPrompt)
                try Task.checkCancellation()
                response = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           urlError.code == .cannotConnectToHost || urlError.code == .networkConnectionLost {
            return "Could not download the model. Check your internet connection and try again."
        }

        return error.localizedDescription
    }
}

#Preview {
    LLMTestView()
}
