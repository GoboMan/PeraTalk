import AVFoundation
import Foundation

/// `AVSpeechSynthesizer` で発話するシンプル TTS クライアント。
/// 今回のスコープではストリーミング断片の高度なバッファリングは行わず、
/// `speak()` / `enqueueFragment()` ともに即時 utterance を投入する。
@MainActor
final class LiveQueuedAVSpeechTTSClient: NSObject, TTSClient {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func warmUp() async throws {}

    func speak(text: String, locale: String, gender: String?) async {
        enqueueUtterance(text: text, locale: locale, gender: gender)
    }

    func enqueueFragment(_ text: String, locale: String, gender: String?) async {
        enqueueUtterance(text: text, locale: locale, gender: gender)
    }

    func flushPendingSpeech(locale: String, gender: String?) async {
        _ = locale
        _ = gender
    }

    func cancelQueuedSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func enqueueUtterance(text: String, locale: String, gender: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        configurePlaybackSessionIfNeeded()

        let utterance = AVSpeechUtterance(string: trimmed)
        if let voice = preferredVoice(locale: locale, gender: gender) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }

    private func preferredVoice(locale: String, gender: String?) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix(locale.lowercased())
        }
        guard !candidates.isEmpty else {
            return AVSpeechSynthesisVoice(language: locale)
        }
        if let g = gender?.lowercased() {
            let target: AVSpeechSynthesisVoiceGender =
                g == "female" ? .female : (g == "male" ? .male : .unspecified)
            if target != .unspecified,
               let match = candidates.first(where: { $0.gender == target }) {
                return match
            }
        }
        return candidates.first
    }

    private func configurePlaybackSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        if session.category == .playAndRecord || session.category == .playback {
            try? session.setActive(true, options: [])
            return
        }
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
    }
}
