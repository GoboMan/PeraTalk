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

// MARK: - Learning log

struct LearningLogScreenPreferences: Codable, Equatable, Sendable {
    /// カレンダー等で使う週の始まり。
    var calendarFirstWeekday: CalendarFirstWeekdayPreference

    init(calendarFirstWeekday: CalendarFirstWeekdayPreference = .system) {
        self.calendarFirstWeekday = calendarFirstWeekday
    }
}

enum CalendarFirstWeekdayPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case sunday
    case monday

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "システムに合わせる"
        case .sunday: return "日曜始まり"
        case .monday: return "月曜始まり"
        }
    }

    /// `Calendar.Component` に合わせた `firstWeekday`（日曜 = 1）。
    func resolvedFirstWeekday(calendar: Calendar) -> Int {
        switch self {
        case .system: return calendar.firstWeekday
        case .sunday: return 1
        case .monday: return 2
        }
    }
}

// MARK: - Conversation

struct ConversationScreenPreferences: Codable, Equatable, Sendable {
    /// 会話タブのプレースホルダー画面で、機能説明ブロックを表示する。
    var showStartScreenGuide: Bool

    init(showStartScreenGuide: Bool = true) {
        self.showStartScreenGuide = showStartScreenGuide
    }
}

// MARK: - Vocabulary list

struct VocabularyListScreenPreferences: Codable, Equatable, Sendable {
    var listDensity: ListRowDensity
    var sortOrder: VocabularyListSortOrder
    /// 一覧カードで品詞バッジを表示する。
    var showPartOfSpeech: Bool
    /// 一覧で補助言語側の定義（例: 日本語訳）を表示する。
    var showJapaneseDefinition: Bool
    /// 一覧でターゲット言語側の定義（英訳）を表示する。
    var showEnglishDefinition: Bool
    /// 一覧で IPA などの発音表記を表示する。
    var showPronunciation: Bool

    init(
        listDensity: ListRowDensity = .comfortable,
        sortOrder: VocabularyListSortOrder = .recentlyAdded,
        showPartOfSpeech: Bool = true,
        showJapaneseDefinition: Bool = true,
        showEnglishDefinition: Bool = true,
        showPronunciation: Bool = true
    ) {
        self.listDensity = listDensity
        self.sortOrder = sortOrder
        self.showPartOfSpeech = showPartOfSpeech
        self.showJapaneseDefinition = showJapaneseDefinition
        self.showEnglishDefinition = showEnglishDefinition
        self.showPronunciation = showPronunciation
    }

    enum CodingKeys: String, CodingKey {
        case listDensity
        case sortOrder
        case showDefinitionPreview
        case showPartOfSpeech
        case showJapaneseDefinition
        case showEnglishDefinition
        case showPronunciation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listDensity = try container.decodeIfPresent(ListRowDensity.self, forKey: .listDensity) ?? .comfortable
        sortOrder = try container.decodeIfPresent(VocabularyListSortOrder.self, forKey: .sortOrder) ?? .recentlyAdded
        let legacyShowDefinitionPreview = try container.decodeIfPresent(Bool.self, forKey: .showDefinitionPreview)
        showPartOfSpeech = try container.decodeIfPresent(Bool.self, forKey: .showPartOfSpeech) ?? true
        showJapaneseDefinition = try container.decodeIfPresent(Bool.self, forKey: .showJapaneseDefinition) ?? true
        showEnglishDefinition = try container.decodeIfPresent(Bool.self, forKey: .showEnglishDefinition) ?? true
        showPronunciation = try container.decodeIfPresent(Bool.self, forKey: .showPronunciation) ?? true
        if legacyShowDefinitionPreview == false {
            showJapaneseDefinition = false
            showEnglishDefinition = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(listDensity, forKey: .listDensity)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(showPartOfSpeech, forKey: .showPartOfSpeech)
        try container.encode(showJapaneseDefinition, forKey: .showJapaneseDefinition)
        try container.encode(showEnglishDefinition, forKey: .showEnglishDefinition)
        try container.encode(showPronunciation, forKey: .showPronunciation)
    }
}

enum ListRowDensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case comfortable
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comfortable: return "広め"
        case .compact: return "詰めて表示"
        }
    }
}

enum VocabularyListSortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case recentlyAdded
    case headwordAZ

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recentlyAdded: return "追加が新しい順"
        case .headwordAZ: return "見出し語（A〜Z）"
        }
    }
}

extension CachedProfile {
    var screenDisplayPreferencesOrDefault: ScreenDisplayPreferences {
        ScreenDisplayPreferences.decodeOrDefault(screenDisplayPreferencesData)
    }
}
