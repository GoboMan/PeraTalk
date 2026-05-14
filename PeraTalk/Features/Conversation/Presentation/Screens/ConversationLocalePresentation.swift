import Foundation

enum ConversationLocalePresentation {
    static func flagEmoji(for locale: String) -> String {
        let l = locale.lowercased()
        if l.contains("gb") || l.contains("uk") { return "🇬🇧" }
        if l.contains("au") { return "🇦🇺" }
        if l.contains("us") || l.hasPrefix("en") { return "🇺🇸" }
        return "🌐"
    }

    static func regionLabel(for locale: String) -> String {
        let l = locale.lowercased()
        if l.contains("gb") || l.contains("uk") { return "イギリス" }
        if l.contains("au") { return "オーストラリア" }
        if l.contains("us") { return "アメリカ" }
        if l.hasPrefix("en") { return "英語圏" }
        return locale
    }
}
