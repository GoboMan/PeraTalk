import Foundation

/// 辞典・マイ単語帳ともに「この用法で例文に載せる英語綴り」を決める単一ソース。
///
/// **優先順**: 明示された `studyHeadword` → `surfaces` 規則 → 親レマ見出し。
enum LemmaStudyEmbeddingText {
    // MARK: - Pack import（`CachedLemmaUsage` 構築直後、`surfaces` は既に挿入済み）

    static func studyHeadwordForPackImport(
        explicitPack: String?,
        vocabularyKind: VocabularyKind,
        surfaces: [CachedLemmaSurface],
        lemmaText: String
    ) -> String {
        if let trimmed = trimmedNonEmpty(explicitPack) {
            return trimmed
        }
        return deriveFromSurfaces(kind: vocabularyKind, surfaces: surfaces)
            ?? lemmaText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 既存 `CachedLemmaUsage` から読む

    static func embeddingText(for vocabularyKind: VocabularyKind, usage: CachedLemmaUsage) -> String? {
        if let explicit = trimmedNonEmpty(usage.studyHeadword) {
            return explicit
        }
        if let derived = deriveFromSurfaces(kind: vocabularyKind, surfaces: usage.surfaces) {
            return derived
        }
        return trimmedNonEmpty(usage.lemma?.lemmaText)
    }

    /// `kind` に一致する最初の `CachedLemmaUsage`（`position` 昇順）。
    static func embeddingText(for vocabularyKind: VocabularyKind, in lemma: CachedLemma) -> String? {
        let usages = lemma.usages
            .filter { usageMatches($0, vocabularyKind: vocabularyKind) }
            .sorted { $0.position < $1.position }
        guard let usage = usages.first else { return trimmedNonEmpty(lemma.lemmaText) }
        return embeddingText(for: vocabularyKind, usage: usage)
    }

    /// `SeedVocabularyAddFormFromLemmaUseCase` の IPA 選択と同じ優先順で **text** を取る。
    static func deriveFromSurfaces(kind: VocabularyKind, surfaces: [CachedLemmaSurface]) -> String? {
        func trimmedSurface(_ form: LemmaSurfaceFormKind) -> String? {
            let raw = surfaces
                .first { $0.formKindRaw == form.rawValue }?
                .text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            return raw.isEmpty ? nil : raw
        }

        switch kind {
        case .verb, .phrasalVerb:
            return trimmedSurface(.verbBase) ?? trimmedSurface(.lemmaBase)
        case .adjective:
            return trimmedSurface(.adjPositive) ?? trimmedSurface(.lemmaBase)
        case .noun:
            return trimmedSurface(.nounSingular) ?? trimmedSurface(.lemmaBase)
        case .adverb:
            return trimmedSurface(.advPositive) ?? trimmedSurface(.lemmaBase)
        case .preposition, .conjunction, .pronoun, .interjection, .idiom:
            return trimmedSurface(.lemmaBase)
        }
    }

    // MARK: - Private

    private static func usageMatches(_ usage: CachedLemmaUsage, vocabularyKind: VocabularyKind) -> Bool {
        if usage.kind == vocabularyKind.rawValue { return true }
        if let alternate = VocabularyKind(kindString: usage.kind), alternate == vocabularyKind {
            return true
        }
        return false
    }

    private static func trimmedNonEmpty(_ s: String?) -> String? {
        guard let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
