import Foundation
import SwiftUI

/// 単語帳の用法タブ（Kind）・辞典パックの `pos` と整合する。
///
/// JSON / API では `rawValue`（英語スネークケース）を使う。
enum VocabularyKind: String, Codable, CaseIterable {
    // 主要な品詞（略号: n. / v. / adj. / adv. / prep. / conj. / pron. / int.）
    case noun
    case verb
    case adjective
    case adverb
    case preposition
    case conjunction
    case pronoun
    case interjection
    /// 句動詞（phr. v.）
    case phrasalVerb = "phrasal_verb"
    /// 熟語・慣用句（idm. / phr.）
    case idiom

    var displayName: String {
        switch self {
        case .noun: "名詞"
        case .verb: "動詞"
        case .adjective: "形容詞"
        case .adverb: "副詞"
        case .preposition: "前置詞"
        case .conjunction: "接続詞"
        case .pronoun: "代名詞"
        case .interjection: "間投詞"
        case .phrasalVerb: "句動詞"
        case .idiom: "熟語・慣用句"
        }
    }

    var englishLabel: String {
        switch self {
        case .noun: "Noun"
        case .verb: "Verb"
        case .adjective: "Adjective"
        case .adverb: "Adverb"
        case .preposition: "Preposition"
        case .conjunction: "Conjunction"
        case .pronoun: "Pronoun"
        case .interjection: "Interjection"
        case .phrasalVerb: "Phrasal Verb"
        case .idiom: "Idiom"
        }
    }

    var badgeColor: Color {
        switch self {
        case .noun: Color.blue
        case .verb: Color.red
        case .adjective: Color.orange
        case .adverb: Color.purple
        case .preposition: Color.teal
        case .conjunction: Color.indigo
        case .pronoun: Color.cyan
        case .interjection: Color.pink
        case .phrasalVerb: Color.green
        case .idiom: Color.brown
        }
    }

    init?(kindString: String) {
        if kindString == "phrasing" {
            self = .phrasalVerb
            return
        }
        self.init(rawValue: kindString)
    }
}
