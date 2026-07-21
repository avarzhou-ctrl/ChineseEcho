//
//  SpeechAudioEngine.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/14.
//

import AVFoundation
import Observation

@Observable
final class SpeechAudioEngine: NSObject, AVSpeechSynthesizerDelegate {
    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()
    // Keep the picker focused on voices that sound good for dictation.
    private let preferredVoiceNames = ["Yu-shu", "Tingting", "Li-Mu"]

    // Dictation playback uses this callback to repeat only after speech truly finishes.
    @ObservationIgnored
    var onUtteranceFinished: (() -> Void)?

    // AVSpeechUtterance expects Float values for speech tuning.
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var pitchMultiplier: Float = 1.0
    var interWordPause: TimeInterval = 1.25
    var selectedVoice: AVSpeechSynthesisVoice?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

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

    // Prefer the installed female Siri voice without depending on its localized display name.
    var defaultFemaleVoice: AVSpeechSynthesisVoice? {
        voices.first { $0.gender == .female && $0.identifier.contains(".siri_") }
            ?? voices.first { $0.name == "Tingting" }
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }
    
    func speak(_ text: String) {
        // Utterances snapshot the current voice, rate, and pitch at speak time.
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = rate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.postUtteranceDelay = interWordPause

        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onUtteranceFinished?()
    }
}
