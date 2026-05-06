import Foundation

struct SaveVocabularyAddFormUseCase {
    let vocabularyService: any VocabularyService

    func execute(_ payload: VocabularyAddFormPayload) async throws {
        try await vocabularyService.upsertAddForm(payload)
    }
}
