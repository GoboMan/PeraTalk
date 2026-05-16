import Foundation

/// アシスタント応答の生成状態（非ストリーミング想定）。
enum AssistantReplyPhase: Equatable, Sendable {
    case idle
    case generating
    case failedCancelled
    case failedError
}
