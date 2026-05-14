import AVFoundation
import Foundation

/// フラグメントをキューし連続読みする。読み出し側で「意味のある塊」に整形すること（チャンキング）。
@MainActor
final class LiveQueuedAVSpeechTTSClient: NSObject, AVSpeechSynthesizerDelegate, TTSClient {
    private let synthesizer = AVSpeechSynthesizer()
    private var fragmentQueue: [String] = []
    /// フラグメント列に使う音声・直近値を保持する（キュー dequeue 側で適用）。
    private var queuedLocaleIdentifier: String = Locale.current.identifier
    private var queuedGender: String?
    /// `speak` 全体の完了。
    private var awaitingSingleSpeak: CheckedContinuation<Void, Never>?
    /// flush 側で再生が尽きたら resume。
    private var awaitingDrain: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking || !fragmentQueue.isEmpty
    }

    func speak(text: String, locale: String, gender: String?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        fragmentQueue.removeAll()
        queuedLocaleIdentifier = locale
        queuedGender = gender
        synthesizer.stopSpeaking(at: .immediate)
        awaitingSingleSpeak?.resume()
        awaitingDrain?.resume()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.awaitingSingleSpeak = continuation
            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = Self.pickVoice(localeIdentifier: locale, genderHint: gender)
            utterance.rate = AVSpeechUtteranceMaximumSpeechRate * 0.45
            self.synthesizer.speak(utterance)
        }
    }

    func enqueueFragment(_ text: String, locale: String, gender: String?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        queuedLocaleIdentifier = locale
        queuedGender = gender
        fragmentQueue.append(trimmed)

        if awaitingSingleSpeak == nil, !synthesizer.isSpeaking {
            speakNextQueued()
        }
    }

    func flushPendingSpeech(locale: String, gender: String?) async {
        queuedLocaleIdentifier = locale
        queuedGender = gender
        guard !fragmentQueue.isEmpty || synthesizer.isSpeaking else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if fragmentQueue.isEmpty, !self.synthesizer.isSpeaking {
                continuation.resume(); return
            }
            awaitingDrain = continuation
            if !self.synthesizer.isSpeaking {
                speakNextQueued()
            }
        }
    }

    func cancelQueuedSpeech() {
        awaitingSingleSpeak?.resume(); awaitingSingleSpeak = nil
        awaitingDrain?.resume(); awaitingDrain = nil
        synthesizer.stopSpeaking(at: .immediate)
        fragmentQueue.removeAll()
    }

    func stop() {
        cancelQueuedSpeech()
    }

    nonisolated func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if awaitingSingleSpeak != nil {
                awaitingSingleSpeak?.resume(); awaitingSingleSpeak = nil
                return
            }
            if fragmentQueue.isEmpty {
                awaitingDrain?.resume(); awaitingDrain = nil
                return
            }
            speakNextQueued()
        }
    }

    nonisolated func speechSynthesizer(_ synth: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            awaitingSingleSpeak?.resume(); awaitingSingleSpeak = nil
            awaitingDrain?.resume(); awaitingDrain = nil
            fragmentQueue.removeAll()
        }
    }

    private func speakNextQueued() {
        guard !fragmentQueue.isEmpty else {
            awaitingDrain?.resume(); awaitingDrain = nil
            return
        }
        let text = fragmentQueue.removeFirst()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.pickVoice(localeIdentifier: queuedLocaleIdentifier, genderHint: queuedGender)
        utterance.rate = AVSpeechUtteranceMaximumSpeechRate * 0.45
        synthesizer.speak(utterance)
    }

    nonisolated private static func pickVoice(localeIdentifier: String, genderHint: String?) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let langPrefix = localeIdentifier.split(separator: "-").first.map({ String($0).lowercased() })
            ?? String(localeIdentifier.prefix(2)).lowercased()

        let candidatesFiltered = voices.filter { voice in
            voice.language.lowercased().hasPrefix(langPrefix)
        }

        let candidates = candidatesFiltered.isEmpty
            ? voices.filter { $0.language.lowercased().hasPrefix("en") }
            : candidatesFiltered

        guard !candidates.isEmpty else { return AVSpeechSynthesisVoice(language: "en-US") }

        func byQuality(_ xs: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            xs.max(by: { $0.quality.rawValue < $1.quality.rawValue }) ?? xs.first
        }

        let hint = genderHint?.lowercased()
        if hint == "male" || hint == "m" {
            let narrowed = candidates.filter { $0.gender == .male }
            return byQuality(narrowed.isEmpty ? candidates : narrowed)
        }
        if hint == "female" || hint == "f" {
            let narrowed = candidates.filter { $0.gender == .female }
            return byQuality(narrowed.isEmpty ? candidates : narrowed)
        }
        return byQuality(candidates)
    }
}
