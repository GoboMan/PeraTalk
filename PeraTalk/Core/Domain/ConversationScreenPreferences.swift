import Foundation

struct ConversationScreenPreferences: Codable, Equatable, Sendable {
    /// 会話タブのプレースホルダー画面で、機能説明ブロックを表示する。
    var showStartScreenGuide: Bool

    init(showStartScreenGuide: Bool = true) {
        self.showStartScreenGuide = showStartScreenGuide
    }
}
