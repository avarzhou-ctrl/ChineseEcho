//
//  SpeechAudioEngine.swift
//  ChineseEcho
//
//  Created by Ava Zhou on 2026/7/14.
//

import AVFoundation
import Observation
import OSLog

// Wraps AVSpeechSynthesizer with observable Mandarin voice, rate, pitch, and completion controls.
@MainActor
@Observable
final class SpeechAudioEngine: NSObject, AVSpeechSynthesizerDelegate {
    @ObservationIgnored
    private var synthesizer: AVSpeechSynthesizer
    @ObservationIgnored private let makeSynthesizer: () -> AVSpeechSynthesizer
    private let startupTimeout: Double
    @ObservationIgnored private var activeUtterance: AVSpeechUtterance?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var hasRetried = false
    private let logger = Logger(subsystem: "ChineseEcho", category: "SpeechRecovery")
    // Keep the picker focused on voices that sound good for dictation.
    private let preferredVoiceNames = ["Yu-shu", "Tingting", "Li-Mu"]

    // Dictation playback uses this callback to repeat only after speech truly finishes.
    @ObservationIgnored
    var onUtteranceFinished: (() -> Void)?
    @ObservationIgnored
    var onPlaybackFailed: (() -> Void)?

    // AVSpeechUtterance expects Float values for speech tuning.
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var pitchMultiplier: Float = 1.0
    var interWordPause: TimeInterval = 1.25
    var selectedVoice: AVSpeechSynthesisVoice?

    init(
        makeSynthesizer: @escaping () -> AVSpeechSynthesizer = { AVSpeechSynthesizer() },
        startupTimeout: Double = 8
    ) {
        self.makeSynthesizer = makeSynthesizer
        self.startupTimeout = startupTimeout
        synthesizer = makeSynthesizer()
        super.init()
        synthesizer.delegate = self
        configureFromPreferences()
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

    func configureFromPreferences(_ defaults: UserDefaults = .standard) {
        rate = Float(
            defaults.object(forKey: AppPreferenceKey.speechRate) as? Double
                ?? AppPreferenceDefault.speechRate
        )
        pitchMultiplier = Float(
            defaults.object(forKey: AppPreferenceKey.speechPitch) as? Double
                ?? AppPreferenceDefault.speechPitch
        )
        interWordPause =
            defaults.object(forKey: AppPreferenceKey.interWordPause) as? Double
            ?? AppPreferenceDefault.interWordPause

        let savedIdentifier = defaults.string(forKey: AppPreferenceKey.voiceIdentifier) ?? ""
        let profile = defaults.string(forKey: AppPreferenceKey.pronunciationProfile)
            ?? AppPreferenceDefault.pronunciationProfile
        selectedVoice = voices.first { $0.identifier == savedIdentifier }
            ?? voice(for: profile)
            ?? defaultFemaleVoice
    }

    private func voice(for profile: String) -> AVSpeechSynthesisVoice? {
        let language = profile == "Taiwanese Mandarin" ? "zh-TW" : "zh-CN"
        return voices.first { $0.language == language && $0.gender == .female }
            ?? voices.first { $0.language == language }
            ?? AVSpeechSynthesisVoice(language: language)
    }
    
    func speak(_ text: String) {
        stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        hasRetried = false
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = rate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.postUtteranceDelay = interWordPause
        begin(utterance)
    }

    func stop() {
        watchdog?.cancel()
        watchdog = nil
        activeUtterance = nil
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func begin(_ utterance: AVSpeechUtterance) {
        // A fresh synthesizer also makes manual replay recover from silent “success”.
        synthesizer = makeSynthesizer()
        synthesizer.delegate = self
        activeUtterance = utterance
        armWatchdog(seconds: startupTimeout)
        synthesizer.speak(utterance)
    }

    private func armWatchdog(seconds: Double) {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch { return }
            self?.recover()
        }
    }

    private func recover() {
        guard let previous = activeUtterance else { return }
        stop()
        guard !hasRetried else {
            logger.error("Speech recovery exhausted; playback stopped. Use replay to try again.")
            onPlaybackFailed?()
            return
        }
        hasRetried = true
        logger.notice("Rebuilding speech synthesizer and retrying interrupted or stalled playback.")
        let utterance = AVSpeechUtterance(string: previous.speechString)
        // Keep the pronunciation region and never overwrite the user's saved voice choice.
        let language = previous.voice?.language ?? "zh-CN"
        utterance.voice = AVSpeechSynthesisVoice.speechVoices().first {
            $0.language == language && $0.quality == .default
                && !$0.identifier.contains("com.apple.eloquence")
        } ?? AVSpeechSynthesisVoice(language: language) ?? previous.voice
        utterance.rate = previous.rate
        utterance.pitchMultiplier = previous.pitchMultiplier
        utterance.postUtteranceDelay = previous.postUtteranceDelay
        begin(utterance)
    }

    private enum SpeechEvent: Sendable { case started, cancelled, finished }

    nonisolated private func receive(
        _ event: SpeechEvent, from sender: AVSpeechSynthesizer, utterance: AVSpeechUtterance
    ) {
        let senderID = ObjectIdentifier(sender)
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, let current = self.activeUtterance,
                  ObjectIdentifier(self.synthesizer) == senderID,
                  ObjectIdentifier(current) == utteranceID else { return }
            switch event {
            case .started:
                // Allow long samples and slow rates even without word-progress callbacks.
                self.armWatchdog(seconds: max(30, Double(current.speechString.count) * 3)
                    + current.postUtteranceDelay)
            case .cancelled:
                self.recover()
            case .finished:
                self.watchdog?.cancel()
                self.watchdog = nil
                self.activeUtterance = nil
                self.onUtteranceFinished?()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        receive(.started, from: synthesizer, utterance: utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        receive(.cancelled, from: synthesizer, utterance: utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        receive(.finished, from: synthesizer, utterance: utterance)
    }
}
