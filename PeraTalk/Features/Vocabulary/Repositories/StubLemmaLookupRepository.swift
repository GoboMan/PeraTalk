import Foundation

struct StubLemmaLookupRepository: LemmaLookupRepository {
    func searchCandidates(trimmedQuery: String) throws -> [LemmaSearchCandidate] { [] }
    func fetchLemma(stableLemmaId: UUID) throws -> CachedLemma? { nil }
}
