//
//  SpeechAudioEngine.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/14.
//

import AVFoundation
import Observation

@Observable
final class SpeechAudioEngine {
    private let synthesizer = AVSpeechSynthesizer()
    // Keep the picker focused on voices that sound good for dictation.
    private let preferredVoiceNames = ["Yu-shu", "Li-Mu", "Tingting"]

    // AVSpeechUtterance expects Float values for speech tuning.
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var pitchMultiplier: Float = 1.0
    var selectedVoice: AVSpeechSynthesisVoice?

    // Prefer natural Apple Chinese voices for dictation and hide novelty/accessibility voices.
    var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { preferredVoiceNames.contains($0.name) }
            .filter { !$0.identifier.contains("com.apple.eloquence") }
            .sorted { lhs, rhs in
                // Preserve our preferred order instead of Apple's system order.
                let lhsIndex = preferredVoiceNames.firstIndex(of: lhs.name) ?? Int.max
                let rhsIndex = preferredVoiceNames.firstIndex(of: rhs.name) ?? Int.max
                return lhsIndex < rhsIndex
            }
    }
    
    func speak(_ text: String) {
        // Utterances snapshot the current voice, rate, and pitch at speak time.
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = rate
        utterance.pitchMultiplier = pitchMultiplier

        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
