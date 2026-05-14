import Foundation

enum LemmaParadigmPresenter {
    static func orderedForms(for vocabularyKind: VocabularyKind) -> [LemmaSurfaceFormKind] {
        switch vocabularyKind {
        case .verb, .phrasalVerb:
            LemmaSurfaceFormKind.verbInflectionDisplayOrder
        case .adjective:
            LemmaSurfaceFormKind.adjectiveInflectionDisplayOrder
        case .noun:
            LemmaSurfaceFormKind.nounInflectionDisplayOrder
        case .adverb:
            LemmaSurfaceFormKind.adverbInflectionDisplayOrder + [.lemmaBase]
        default:
            [.lemmaBase]
        }
    }

    /// 指定用法の活用行（説明ラベル・語形・IPA）。
    static func rows(for usage: CachedLemmaUsage) -> [(label: String, text: String, ipa: String?)] {
        guard let vk = VocabularyKind(rawValue: usage.kind) ?? VocabularyKind(kindString: usage.kind) else {
            return []
        }
        let forms = orderedForms(for: vk)
        return forms.compactMap { form in
            guard let surface = usage.surfaces.first(where: { $0.formKindRaw == form.rawValue }) else {
                return nil
            }
            let ipa: String?
            switch form {
            case .verbBase, .adjPositive, .nounSingular, .advPositive, .lemmaBase:
                ipa = nil
            default:
                ipa = surface.ipa
            }
            return (form.paradigmLabelJapanese, surface.text, ipa)
        }
    }

    static func usageHasInflectionRows(_ usage: CachedLemmaUsage) -> Bool {
        guard let vk = VocabularyKind(rawValue: usage.kind) ?? VocabularyKind(kindString: usage.kind) else {
            return false
        }
        return orderedForms(for: vk).contains { form in
            usage.surfaces.contains { $0.formKindRaw == form.rawValue }
        }
    }
}
