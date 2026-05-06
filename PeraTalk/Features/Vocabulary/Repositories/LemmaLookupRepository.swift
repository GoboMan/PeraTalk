import Foundation
import SwiftData
import SwiftData

/// SwiftData に投入済みの `CachedLemma` を閲覧用に検索・取得する Port。
protocol LemmaLookupRepository {
    func searchCandidates(trimmedQuery: String) throws -> [LemmaSearchCandidate]
    func fetchLemma(stableLemmaId: UUID) throws -> CachedLemma?
}

struct StubLemmaLookupRepository: LemmaLookupRepository {
    func searchCandidates(trimmedQuery: String) throws -> [LemmaSearchCandidate] { [] }
    func fetchLemma(stableLemmaId: UUID) throws -> CachedLemma? { nil }
}
