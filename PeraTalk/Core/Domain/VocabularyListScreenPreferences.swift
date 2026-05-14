import Foundation

struct VocabularyListScreenPreferences: Codable, Equatable, Sendable {
    var listDensity: ListRowDensity
    var sortOrder: VocabularyListSortOrder
    /// 一覧で補助言語側の定義（例: 日本語訳）を表示する。
    var showJapaneseDefinition: Bool
    /// 一覧でターゲット言語側の定義（英訳）を表示する。
    var showEnglishDefinition: Bool
    /// 一覧で IPA などの発音表記を表示する。
    var showPronunciation: Bool

    init(
        listDensity: ListRowDensity = .comfortable,
        sortOrder: VocabularyListSortOrder = .recentlyAdded,
        showJapaneseDefinition: Bool = true,
        showEnglishDefinition: Bool = true,
        showPronunciation: Bool = true
    ) {
        self.listDensity = listDensity
        self.sortOrder = sortOrder
        self.showJapaneseDefinition = showJapaneseDefinition
        self.showEnglishDefinition = showEnglishDefinition
        self.showPronunciation = showPronunciation
    }

    enum CodingKeys: String, CodingKey {
        case listDensity
        case sortOrder
        case showDefinitionPreview
        case showJapaneseDefinition
        case showEnglishDefinition
        case showPronunciation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listDensity = try container.decodeIfPresent(ListRowDensity.self, forKey: .listDensity) ?? .comfortable
        sortOrder = try container.decodeIfPresent(VocabularyListSortOrder.self, forKey: .sortOrder) ?? .recentlyAdded
        let legacyShowDefinitionPreview = try container.decodeIfPresent(Bool.self, forKey: .showDefinitionPreview)
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
        try container.encode(showJapaneseDefinition, forKey: .showJapaneseDefinition)
        try container.encode(showEnglishDefinition, forKey: .showEnglishDefinition)
        try container.encode(showPronunciation, forKey: .showPronunciation)
    }
}
