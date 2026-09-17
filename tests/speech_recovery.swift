import AVFoundation

// Only preference defaults are stubbed; the production speech engine runs unchanged.
enum AppPreferenceKey {
    static let speechRate = "speechRate"
    static let speechPitch = "speechPitch"
    static let interWordPause = "interWordPause"
    static let voiceIdentifier = "speechVoiceIdentifier"
    static let pronunciationProfile = "pronunciationProfile"
}
enum AppPreferenceDefault {
    static let speechRate = 0.5
    static let speechPitch = 1.0
    static let interWordPause = 1.25
    static let pronunciationProfile = "Mainland Mandarin"
}

@MainActor
final class SilentSynthesizer: AVSpeechSynthesizer {
    var submitted: AVSpeechUtterance?
    override func speak(_ utterance: AVSpeechUtterance) { submitted = utterance }
    override func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { true }
}

@main
struct SpeechRecoveryTests {
    @MainActor static func main() async throws {
        var instances: [SilentSynthesizer] = []
        let engine = SpeechAudioEngine(makeSynthesizer: {
            let instance = SilentSynthesizer()
            instances.append(instance)
            return instance
        }, startupTimeout: 0.05)
        var failures = 0
        engine.onPlaybackFailed = { failures += 1 }
        var completions = 0
        engine.onUtteranceFinished = { completions += 1 }

        engine.speak("你好")
        let original = instances.last!
        let originalUtterance = original.submitted!
        for _ in 0..<40 where failures == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }
        precondition(instances.count == 3, "A stalled request must retry exactly once")
        precondition(instances.last!.submitted!.speechString == "你好")
        precondition(completions == 0, "Failure must not advance dictation repeats")
        precondition(failures == 1, "Exhausted recovery must pause the dictation UI")

        engine.speak("再见")
        let stoppedCount = instances.count
        engine.stop()
        try await Task.sleep(for: .milliseconds(100))
        precondition(instances.count == stoppedCount, "Stop must cancel recovery")

        engine.speak("学习")
        let current = instances.last!
        let currentUtterance = current.submitted!
        engine.speechSynthesizer(original, didFinish: originalUtterance)
        engine.speechSynthesizer(original, didCancel: originalUtterance)
        try await Task.sleep(for: .milliseconds(10))
        precondition(completions == 0 && instances.last === current, "Stale callbacks must be ignored")
        engine.speechSynthesizer(current, didFinish: currentUtterance)
        engine.speechSynthesizer(current, didFinish: currentUtterance)
        try await Task.sleep(for: .milliseconds(100))
        precondition(completions == 1 && instances.last === current, "Completion must fire once and cancel recovery")

        engine.speak("较长的朗读")
        let started = instances.last!
        engine.speechSynthesizer(started, didStart: started.submitted!)
        try await Task.sleep(for: .milliseconds(100))
        precondition(instances.last === started, "Started speech must outlive the startup deadline")
        engine.stop()

        engine.speak("朋友")
        let cancelled = instances.last!
        engine.speechSynthesizer(cancelled, didCancel: cancelled.submitted!)
        try await Task.sleep(for: .milliseconds(10))
        precondition(instances.last !== cancelled, "Unexpected cancellation must rebuild the engine")
        let retry = instances.last!
        engine.speechSynthesizer(retry, didCancel: retry.submitted!)
        try await Task.sleep(for: .milliseconds(10))
        precondition(instances.last === retry, "Cancellation retries must be bounded")

        engine.speak("旧词")
        engine.speak("新词")
        let newest = instances.last!
        engine.speechSynthesizer(newest, didFinish: newest.submitted!)
        try await Task.sleep(for: .milliseconds(100))
        precondition(instances.last === newest, "Replacement must cancel the previous watchdog")
        print("Speech recovery tests passed")
    }
}
