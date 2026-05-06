import Foundation

/// 辞典パックにおける「表面形の枠」。JSON `form_kind` / `formKind` と一致させる。
enum LemmaSurfaceFormKind: String, Codable, CaseIterable, Sendable {
    case verbBase = "verb_base"
    case verbThirdPersonSingular = "verb_third_person_singular"
    case verbPresentParticiple = "verb_present_participle"
    case verbPast = "verb_past"
    case verbPastParticiple = "verb_past_participle"

    case adjPositive = "adj_positive"
    case adjComparative = "adj_comparative"
    case adjSuperlative = "adj_superlative"

    case nounSingular = "noun_singular"
    case nounPlural = "noun_plural"

    /// 副詞の原級・比較級・最上級（形容詞と同様の枠）。
    case advPositive = "adv_positive"
    case advComparative = "adv_comparative"
    case advSuperlative = "adv_superlative"

    /// 活用枠がない語の代表形（前置詞・接続詞・代名詞・間投詞・句動詞・熟語など1形のみのとき）。
    case lemmaBase = "lemma_base"
}

extension LemmaSurfaceFormKind {
    /// 詳細画面の活用表での表示名。
    var paradigmLabelJapanese: String {
        switch self {
        case .verbBase: "原形"
        case .verbThirdPersonSingular: "三人称単数現在"
        case .verbPresentParticiple: "現在分詞／動名詞 (-ing)"
        case .verbPast: "過去形"
        case .verbPastParticiple: "過去分詞"
        case .adjPositive: "原級"
        case .adjComparative: "比較級"
        case .adjSuperlative: "最上級"
        case .nounSingular: "単数"
        case .nounPlural: "複数"
        case .advPositive: "副詞（原級）"
        case .advComparative: "副詞（比較級）"
        case .advSuperlative: "副詞（最上級）"
        case .lemmaBase: "標準形"
        }
    }

    /// 動詞の表示順。
    static let verbInflectionDisplayOrder: [LemmaSurfaceFormKind] = [
        .verbBase,
        .verbThirdPersonSingular,
        .verbPresentParticiple,
        .verbPast,
        .verbPastParticiple,
    ]

    /// 形容詞の表示順。
    static let adjectiveInflectionDisplayOrder: [LemmaSurfaceFormKind] = [
        .adjPositive,
        .adjComparative,
        .adjSuperlative,
    ]
}
