import Foundation

enum AuxiliaryLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case korean = "ko"
    case spanish = "es"
    case portuguese = "pt"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .japanese: "日本語"
        case .chineseSimplified: "简体中文"
        case .chineseTraditional: "繁體中文"
        case .korean: "한국어"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .french: "Français"
        case .german: "Deutsch"
        }
    }

    var englishName: String {
        switch self {
        case .english: "English"
        case .japanese: "Japanese"
        case .chineseSimplified: "Simplified Chinese"
        case .chineseTraditional: "Traditional Chinese"
        case .korean: "Korean"
        case .spanish: "Spanish"
        case .portuguese: "Portuguese"
        case .french: "French"
        case .german: "German"
        }
    }

    var definitionPlaceholder: String {
        switch self {
        case .english: "Enter definition in English"
        case .japanese: "日本語の定義を入力"
        case .chineseSimplified: "输入中文定义"
        case .chineseTraditional: "輸入中文定義"
        case .korean: "한국어 정의를 입력"
        case .spanish: "Ingrese la definición en español"
        case .portuguese: "Insira a definição em português"
        case .french: "Entrez la définition en français"
        case .german: "Definition auf Deutsch eingeben"
        }
    }

    var translationLabel: String {
        switch self {
        case .english: "English"
        case .japanese: "和訳"
        case .chineseSimplified: "中文翻译"
        case .chineseTraditional: "中文翻譯"
        case .korean: "한국어 번역"
        case .spanish: "Traducción"
        case .portuguese: "Tradução"
        case .french: "Traduction"
        case .german: "Übersetzung"
        }
    }

    var verbDefinitionRule: String {
        switch self {
        case .japanese:
            return "Intransitive verbs end with する (e.g. 勉強する). Transitive verbs end with 〜を…する (e.g. 〜を割り当てる)."
        case .korean:
            return "Intransitive verbs end with 하다 (e.g. 공부하다). Transitive verbs end with ~을/를 ...하다 (e.g. ~을 할당하다)."
        default:
            return ""
        }
    }

    static var systemDefault: AuxiliaryLanguage {
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch langCode {
        case "en": return .english
        case "ja": return .japanese
        case "zh":
            let script = Locale.current.language.script?.identifier
            return script == "Hant" ? .chineseTraditional : .chineseSimplified
        case "ko": return .korean
        case "es": return .spanish
        case "pt": return .portuguese
        case "fr": return .french
        case "de": return .german
        default: return .english
        }
    }
}
