import Foundation

/// プラン方針: ストリーム中は常に部分的なテキストが存在しうる。UI と永続化の判断に `phase` を使う。
enum AssistantReplyStreamPhase: Equatable, Sendable {
    case idle
    case connecting
    case streaming
    case completedNormally
    case completedTruncatedStream
    case failedCancelled
    case failedError
}
