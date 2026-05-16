import Foundation
import WhisperKit

/// WhisperKit による英語向け音声転写クライアント。
/// 初回 transcribe または `warmUp()` のタイミングでモデルをダウンロード／ロードする。
///
/// 設計上のポイント:
/// - WhisperKit は Sendable 非準拠なので、`@MainActor` で完結させて他 actor へ持ち出さない。
/// - 並行 transcribe 要求にも備えて、ロード中タスクは `Task<Void, Error>` で共有し、
///   完了結果は `pipeline` プロパティに格納する（Task 越しに WhisperKit を渡さない）。
@MainActor
final class WhisperKitSpeechRecognizerClient: SpeechRecognizerClient {
    private var pipeline: WhisperKit?
    private var loadingTask: Task<Void, Error>?

    private let modelName: String

    init(modelName: String = "openai_whisper-small.en") {
        self.modelName = modelName
    }

    func warmUp() async throws {
        try await ensurePipelineLoaded()
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        try await ensurePipelineLoaded()
        guard let pipeline else {
            throw SpeechRecognizerError.pipelineUnavailable
        }
        do {
            let results = try await pipeline.transcribe(audioPath: audioFileURL.path)
            return results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw SpeechRecognizerError.transcriptionFailed(underlying: error)
        }
    }

    private func ensurePipelineLoaded() async throws {
        if pipeline != nil { return }
        if let loadingTask {
            try await loadingTask.value
            return
        }
        let modelName = self.modelName
        let task = Task<Void, Error> { @MainActor [weak self] in
            let created = try await WhisperKit(WhisperKitConfig(model: modelName))
            self?.pipeline = created
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
