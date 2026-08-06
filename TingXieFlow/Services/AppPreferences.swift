import Foundation

enum AppPreferenceKey {
    static let voiceIdentifier = "speechVoiceIdentifier"
    static let pronunciationProfile = "pronunciationProfile"
    static let speechRate = "speechRate"
    static let speechPitch = "speechPitch"
    static let interWordPause = "interWordPause"
    static let repeatCount = "practiceRepeatCount"
    static let automaticProgression = "practiceAutomaticProgression"
    static let keepCardsRevealed = "practiceKeepCardsRevealed"
    static let generatedWordCount = "generatedWordCount"

    static let all = [
        voiceIdentifier,
        pronunciationProfile,
        speechRate,
        speechPitch,
        interWordPause,
        repeatCount,
        automaticProgression,
        keepCardsRevealed,
        generatedWordCount
    ]
}

enum AppPreferenceDefault {
    static let pronunciationProfile = "Mainland Mandarin"
    static let speechRate = 0.5
    static let speechPitch = 1.0
    static let interWordPause = 1.25
    static let repeatCount = 1
    static let automaticProgression = true
    static let keepCardsRevealed = false
    static let generatedWordCount = 8
}

extension UserDefaults {
    func resetTingXiePreferences() {
        AppPreferenceKey.all.forEach(removeObject(forKey:))
    }
}
