import Foundation

/// 音声会話セッションのターン 1 件（ScreenModel 上の表示用）。
/// CachedUtterance とは別物で、永続化と切り離した最小フィールドのみ持つ。
struct VoiceChatTurn: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: String
    let text: String
}
