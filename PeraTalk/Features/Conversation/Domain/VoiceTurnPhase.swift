import Foundation

/// 音声会話 1 ターンの進行フェーズ。UI のボタン/メッセージ切替に使う。
enum VoiceTurnPhase: Equatable, Sendable {
    case idle
    case loadingModel
    case recording
    case transcribing
    case awaitingAssistant
    case speakingAssistant
    case failed(String)
}
