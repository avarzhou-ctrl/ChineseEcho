import Foundation

// Centralizes UserDefaults keys so settings views and playback services stay synchronized.
enum AppPreferenceKey {
    static let voiceIdentifier = "speechVoiceIdentifier"
    static let pronunciationProfile = "pronunciationProfile"
    static let speechRate = "speechRate"
    static let speechPitch = "speechPitch"
    static let interWordPause = "interWordPause"
    static let repeatCount = "practiceRepeatCount"
    static let automaticProgression = "practiceAutomaticProgression"
    static let keepCardsRevealed = "practiceKeepCardsRevealed"

    static let all = [
        voiceIdentifier,
        pronunciationProfile,
        speechRate,
        speechPitch,
        interWordPause,
        repeatCount,
        automaticProgression,
        keepCardsRevealed
    ]
}

// Defines the first-launch values used by speech and practice controls.
enum AppPreferenceDefault {
    static let pronunciationProfile = "Mainland Mandarin"
    static let speechRate = 0.5
    static let speechPitch = 1.0
    static let interWordPause = 1.25
    static let repeatCount = 1
    static let automaticProgression = true
    static let keepCardsRevealed = false
}

// Provides one reset operation for every TingXieFlow-specific preference.
extension UserDefaults {
    func resetTingXiePreferences() {
        AppPreferenceKey.all.forEach(removeObject(forKey:))
    }
}
