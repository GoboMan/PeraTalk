import Foundation
import SwiftData

struct SwiftDataVocabularyRepository: VocabularyRepository {
    let context: ModelContext

    func fetchAll() async throws -> [CachedVocabulary] {
        let descriptor = FetchDescriptor<CachedVocabulary>(
            sortBy: [SortDescriptor(\.cachedAt, order: .reverse)]
        )
        let items = try context.fetch(descriptor)
        return items.filter { !$0.tombstone }
    }

    func fetchById(remoteId: UUID) async throws -> CachedVocabulary? {
        let id = remoteId
        let descriptor = FetchDescriptor<CachedVocabulary>(
            predicate: #Predicate { $0.remoteId == id }
        )
        return try context.fetch(descriptor).first
    }

    func fetchByTagId(tagId: UUID) async throws -> CachedVocabulary? {
        let id = tagId
        let descriptor = FetchDescriptor<CachedVocabulary>()
        let items = try context.fetch(descriptor)
        return items.first { vocab in
            !vocab.tombstone &&
                vocab.vocabularyTagLinks.contains { link in
                    !link.tombstone && link.tag?.remoteId == id
                }
        }
    }

    func search(query: String) async throws -> [CachedVocabulary] {
        let all = try await fetchAll()
        guard !query.isEmpty else { return all }
        return all.filter { $0.headword.localizedStandardContains(query) }
    }

    func save(_ vocabulary: CachedVocabulary) async throws {
        context.insert(vocabulary)
        try context.save()
    }

    func markDeleted(_ vocabulary: CachedVocabulary) async throws {
        vocabulary.tombstone = true
        vocabulary.dirty = true
        try context.save()
    }

    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws {
        let trimmed = payload.headword.trimmingCharacters(in: .whitespaces)
        if let editingId = payload.editingVocabularyRemoteId {
            try updateExisting(editingId: editingId, headword: trimmed, payload: payload)
        } else {
            try createNew(headword: trimmed, payload: payload)
        }
        try context.save()
    }

    private func createNew(headword: String, payload: VocabularyAddFormPayload) throws {
        let vocab = CachedVocabulary(headword: headword)
        context.insert(vocab)
        try saveUsages(vocabulary: vocab, payload: payload)
        try saveTagLinks(vocabulary: vocab, payload: payload)
        try applyLemmaLinks(vocabulary: vocab, payload: payload)
    }

    private func updateExisting(editingId: UUID, headword: String, payload: VocabularyAddFormPayload) throws {
        let id = editingId
        let descriptor = FetchDescriptor<CachedVocabulary>(
            predicate: #Predicate { $0.remoteId == id }
        )
        guard let vocab = try context.fetch(descriptor).first else { return }

        vocab.headword = headword
        vocab.dirty = true

        for usage in vocab.usages { usage.tombstone = true }
        for link in vocab.vocabularyTagLinks { link.tombstone = true }

        try saveUsages(vocabulary: vocab, payload: payload)
        try saveTagLinks(vocabulary: vocab, payload: payload)
        try applyLemmaLinks(vocabulary: vocab, payload: payload)
    }

    private func applyLemmaLinks(vocabulary: CachedVocabulary, payload: VocabularyAddFormPayload) throws {
        if let lid = payload.linkedLemmaStableId {
            let id = lid
            var descriptor = FetchDescriptor<CachedLemma>(
                predicate: #Predicate<CachedLemma> { $0.stableLemmaId == id }
            )
            descriptor.fetchLimit = 1
            vocabulary.lemma = try context.fetch(descriptor).first
        } else {
            vocabulary.lemma = nil
        }

        if let aid = payload.linkedAdjunctLemmaStableId {
            let adjId = aid
            var adjDescriptor = FetchDescriptor<CachedLemma>(
                predicate: #Predicate<CachedLemma> { $0.stableLemmaId == adjId }
            )
            adjDescriptor.fetchLimit = 1
            vocabulary.adjunctLemma = try context.fetch(adjDescriptor).first
        } else {
            vocabulary.adjunctLemma = nil
        }
    }

    private func saveUsages(vocabulary: CachedVocabulary, payload: VocabularyAddFormPayload) throws {
        for (position, usageForm) in payload.usages.enumerated() {
            let usage = CachedVocabularyUsage(
                kind: usageForm.kind.rawValue,
                position: position
            )
            usage.ipa = usageForm.ipa.isEmpty ? nil : usageForm.ipa
            usage.definitionAux = usageForm.definitionAux.isEmpty ? nil : usageForm.definitionAux
            usage.definitionTarget = usageForm.definitionTarget.isEmpty ? nil : usageForm.definitionTarget
            let trimmedStudy = usageForm.studyHeadword.trimmingCharacters(in: .whitespacesAndNewlines)
            usage.studyHeadword = trimmedStudy.isEmpty ? nil : trimmedStudy
            usage.vocabulary = vocabulary
            context.insert(usage)

            for (exPosition, exForm) in usageForm.examples.enumerated() {
                guard !exForm.sentence.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let example = CachedVocabularyExample(
                    sentenceTarget: exForm.sentence,
                    position: exPosition
                )
                example.usage = usage
                context.insert(example)
            }
        }
    }

    private func saveTagLinks(vocabulary: CachedVocabulary, payload: VocabularyAddFormPayload) throws {
        for tagId in payload.selectedTagRemoteIds {
            let tid = tagId
            let descriptor = FetchDescriptor<CachedTag>(
                predicate: #Predicate { $0.remoteId == tid }
            )
            guard let tag = try context.fetch(descriptor).first, !tag.tombstone else { continue }
            let link = CachedVocabularyTagLink()
            link.vocabulary = vocabulary
            link.tag = tag
            context.insert(link)
        }
    }
}
