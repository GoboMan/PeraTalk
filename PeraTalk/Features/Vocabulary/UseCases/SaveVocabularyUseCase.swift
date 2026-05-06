import Foundation

struct SaveVocabularyUseCase {
    let vocabularyService: any VocabularyService

    func execute(vocabulary: CachedVocabulary) async throws {
        try await vocabularyService.save(vocabulary)
    }
}
