import Foundation
import TTSKit

/// argmax `TTSKit`（Qwen3 系オンデバイス TTS）を使った TTSClient 実装。
///
/// - `warmUp()` / `speak()` でモデルを読み込む。未ウォーム時は初回 `play(text:)` に時間がかかることがある。
/// - `cancelQueuedSpeech()` / `stop()` で進行中の再生タスクをキャンセルする。
/// - locale / gender は今回スコープでは未使用（TTSKit は speaker/language を別パラメータで指定）。
@MainActor
final class TTSKitTTSClient: NSObject, TTSClient {
    private var ttsKit: TTSKit?
    private var loadingTask: Task<Void, Error>?
    private var currentPlayTask: Task<Void, Never>?

    var isSpeaking: Bool {
        guard let task = currentPlayTask else { return false }
        return !task.isCancelled
    }

    func warmUp() async throws {
        try await ensureLoaded()
    }

    func speak(text: String, locale: String, gender: String?) async {
        _ = locale
        _ = gender
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try await warmUp()
        } catch {
            return
        }
        guard let ttsKit else { return }

        currentPlayTask?.cancel()
        let task = Task<Void, Never> { @MainActor in
            _ = try? await ttsKit.play(text: trimmed)
        }
        currentPlayTask = task
        await task.value
    }

    func enqueueFragment(_ text: String, locale: String, gender: String?) async {
        await speak(text: text, locale: locale, gender: gender)
    }

    func flushPendingSpeech(locale: String, gender: String?) async {
        _ = locale
        _ = gender
    }

    func cancelQueuedSpeech() {
        currentPlayTask?.cancel()
        currentPlayTask = nil
    }

    func stop() {
        cancelQueuedSpeech()
    }

    private func ensureLoaded() async throws {
        if ttsKit != nil { return }
        if let loadingTask {
            try await loadingTask.value
            return
        }
        let task = Task<Void, Error> { @MainActor [weak self] in
            let created = try await TTSKit(TTSKitConfig())
            self?.ttsKit = created
        }
        loadingTask = task
        do {
            try await task.value
        } catch {
            loadingTask = nil
            throw error
        }
        loadingTask = nil
    }
}
