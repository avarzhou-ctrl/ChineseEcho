//
//  SpeechTestView.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/14.
//

import AVFoundation
import SwiftUI

struct SpeechTestView: View {
    @State private var audioEngine = SpeechAudioEngine()
    @State private var selectedVoiceIdentifier = ""

    private let sampleText = "今天我们练习听写。请仔细听，然后写下来。"

    private var availableVoices: [AVSpeechSynthesisVoice] {
        audioEngine.voices
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            GroupBox {
                Text(sampleText)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.vertical, 6)
            } label: {
                Label("听写测试句", systemImage: "text.bubble")
            }

            voicePicker
            audioControls
            playbackButtons

            Spacer()
        }
        .padding(28)
        .frame(minWidth: 520, minHeight: 420)
        .navigationTitle("Speech Test")
        .onAppear(perform: selectDefaultVoice)
        .onChange(of: selectedVoiceIdentifier) { _, newIdentifier in
            audioEngine.selectedVoice = availableVoices.first { $0.identifier == newIdentifier }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Native Audio Engine", systemImage: "speaker.wave.2")
                .font(.largeTitle.bold())

            Text("Test natural Chinese voices, speed, and pitch before connecting audio controls to Smart 听写.")
                .foregroundStyle(.secondary)
        }
    }

    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Voice Profile", selection: $selectedVoiceIdentifier) {
                voiceOptions(voices: audioEngine.voices)
            }
            .pickerStyle(.menu)
            .disabled(availableVoices.isEmpty)

            if availableVoices.isEmpty {
                Label("None of the preferred Chinese speech voices are installed on this Mac.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let selectedVoice = audioEngine.selectedVoice {
                Text(voiceDescription(selectedVoice))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audioControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            sliderRow(
                title: "Speed",
                valueText: String(format: "%.2f", audioEngine.rate),
                value: $audioEngine.rate,
                range: 0.35...0.65
            )

            sliderRow(
                title: "Pitch",
                valueText: String(format: "%.1fx", audioEngine.pitchMultiplier),
                value: $audioEngine.pitchMultiplier,
                range: 0.7...1.4
            )
        }
    }

    private var playbackButtons: some View {
        HStack(spacing: 12) {
            Button {
                audioEngine.stop()
                audioEngine.speak(sampleText)
            } label: {
                Label("Speak", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(availableVoices.isEmpty)

            Button {
                audioEngine.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func voiceOptions(voices: [AVSpeechSynthesisVoice]) -> some View {
        ForEach(voices, id: \.identifier) { voice in
            Text(voice.name).tag(voice.identifier)
        }

        if voices.isEmpty {
            Text("No preferred voices found").tag("")
        }
    }

    private func voiceDescription(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.name {
        case "Yu-shu", "Li-Mu":
            return "\(voice.name) • Siri Chinese"
        case "Tingting":
            return "\(voice.name) • Compact Chinese"
        default:
            return "\(voice.name) • \(voice.language)"
        }
    }

    private func sliderRow(
        title: String,
        valueText: String,
        value: Binding<Float>,
        range: ClosedRange<Float>
    ) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text(title)
                    .frame(width: 58, alignment: .leading)

                Slider(value: value, in: range)

                Text(valueText)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectDefaultVoice() {
        guard selectedVoiceIdentifier.isEmpty else { return }

        let defaultVoice = availableVoices.first
        selectedVoiceIdentifier = defaultVoice?.identifier ?? ""
        audioEngine.selectedVoice = defaultVoice
    }
}

#Preview {
    SpeechTestView()
}
