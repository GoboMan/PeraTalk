import Foundation

/// 主要タブ画面ごとの表示・レイアウトの好み（ローカル永続）。
struct ScreenDisplayPreferences: Codable, Equatable, Sendable {
    var learningLog: LearningLogScreenPreferences
    var conversation: ConversationScreenPreferences
    var vocabularyList: VocabularyListScreenPreferences

    static let `default` = ScreenDisplayPreferences(
        learningLog: LearningLogScreenPreferences(),
        conversation: ConversationScreenPreferences(),
        vocabularyList: VocabularyListScreenPreferences()
    )

    static func decodeOrDefault(_ data: Data?) -> ScreenDisplayPreferences {
        guard let data, !data.isEmpty else { return .default }
        return (try? JSONDecoder().decode(ScreenDisplayPreferences.self, from: data)) ?? .default
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
