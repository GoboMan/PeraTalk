import Foundation

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case notRecording
    case recordingFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "マイクの利用が許可されていません。設定アプリから許可してください。"
        case .notRecording:
            "録音中ではありません。"
        case let .recordingFailed(error):
            "録音に失敗しました: \(error?.localizedDescription ?? "原因不明")"
        }
    }
}
