import Foundation
import SwiftData

struct SwiftDataLemmaLookupRepository: LemmaLookupRepository {
    let context: ModelContext

    func searchCandidates(trimmedQuery: String) throws -> [LemmaSearchCandidate] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }

        let descriptor = FetchDescriptor<CachedLemma>()
        let all = try context.fetch(descriptor)

        let hits = all.filter { lemma in
            if Self.englishLemmaSearchMatches(lemma.lemmaText, queryLowercased: q) {
                return true
            }
            return lemma.surfaces.contains { surface in
                Self.englishLemmaSearchMatches(surface.text, queryLowercased: q)
            }
        }

        func rank(_ lemma: CachedLemma) -> Int {
            let t = lemma.lemmaText.lowercased()
            if t == q { return 0 }
            if t.hasPrefix(q) { return 1 }
            let tokens = Self.englishLemmaTokens(from: t)
            if tokens.contains(where: { $0.hasPrefix(q) }) { return 2 }
            // 代表レマは一致しないが表面形のみ一致したとき
            return 3
        }

        return hits
            .sorted { lhs, rhs in
                let dr = rank(lhs) - rank(rhs)
                if dr != 0 { return dr < 0 }
                return lhs.lemmaText.localizedCaseInsensitiveCompare(rhs.lemmaText) == .orderedAscending
            }
            .prefix(24)
            .map {
                LemmaSearchCandidate(
                    stableLemmaId: $0.stableLemmaId,
                    lemmaText: $0.lemmaText,
                    posRaw: $0.posRaw,
                    hasParticipleAdjectiveParadigm: Self.lemmaHasParticipleAdjectiveParadigm($0)
                )
            }
    }

    /// 動詞レマに形容詞活用（分詞形容詞）が載っているか。
    private static func lemmaHasParticipleAdjectiveParadigm(_ lemma: CachedLemma) -> Bool {
        guard lemma.posRaw == VocabularyKind.verb.rawValue else { return false }
        return LemmaSurfaceFormKind.adjectiveInflectionDisplayOrder.contains { kind in
            lemma.surfaces.contains { $0.formKindRaw == kind.rawValue }
        }
    }

    /// 英見出し入力用：文字列全体または英単語トークンがクエリで **前方一致** するときのみ true。
    /// `contains` だと `cat` が `education` にマッチする問題を防ぐ。
    private static func englishLemmaSearchMatches(_ text: String, queryLowercased q: String) -> Bool {
        guard !q.isEmpty else { return false }
        let lower = text.lowercased()
        if lower.hasPrefix(q) { return true }
        return englishLemmaTokens(from: lower).contains { $0.hasPrefix(q) }
    }

    private static func englishLemmaTokens(from lowercasedText: String) -> [Substring] {
        lowercasedText.split { char in
            !char.isLetter && !char.isNumber
        }.filter { !$0.isEmpty }
    }

    func fetchLemma(stableLemmaId: UUID) throws -> CachedLemma? {
        let id = stableLemmaId
        var descriptor = FetchDescriptor<CachedLemma>(
            predicate: #Predicate<CachedLemma> { $0.stableLemmaId == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
