import Foundation

struct StubAudioRecorderClient: AudioRecorderClient {
    nonisolated init() {}

    func requestPermission() async -> Bool { true }
    func startRecording() async throws {}
    func stopRecording() async throws -> URL {
        // 動作確認用: ファイルは存在しないため呼び元の transcribe は空文字を返す前提。
        FileManager.default.temporaryDirectory.appendingPathComponent("stub-recording.wav")
    }

    func cancelRecording() async {}
}
