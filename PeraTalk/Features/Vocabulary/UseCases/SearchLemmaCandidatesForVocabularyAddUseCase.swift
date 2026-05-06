import Foundation

struct SearchLemmaCandidatesForVocabularyAddUseCase {
    let lemmaLookupRepository: any LemmaLookupRepository

    func execute(trimmedHeadwordPrefix: String) throws -> [LemmaSearchCandidate] {
        try lemmaLookupRepository.searchCandidates(trimmedQuery: trimmedHeadwordPrefix)
    }
}
