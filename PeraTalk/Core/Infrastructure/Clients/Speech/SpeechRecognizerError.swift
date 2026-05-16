import Foundation

enum SpeechRecognizerError: LocalizedError {
    case pipelineUnavailable
    case transcriptionFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .pipelineUnavailable:
            "音声認識モデルを初期化できませんでした。通信状態や空き容量を確認してください。"
        case let .transcriptionFailed(error):
            "音声の文字起こしに失敗しました: \(error?.localizedDescription ?? "原因不明")"
        }
    }
}
