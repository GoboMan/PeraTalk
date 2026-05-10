import Foundation

/// 単語帳の永続化・オンデバイス草案・発音参照を束ねるアプリケーションサービス。
@MainActor
protocol VocabularyService {
    func save(_ vocabulary: CachedVocabulary) async throws
    func markDeleted(_ vocabulary: CachedVocabulary) async throws
    func fetchByRemoteId(_ remoteId: UUID) async throws -> CachedVocabulary?
    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws
    func bookmarkCandidate(_ candidate: VocabularyCandidate) async throws
    func generateWordDraft(
        headword: String,
        nativeLanguage: AuxiliaryLanguage,
        availableTags: [String]
    ) async throws -> WordDraft
    /// レマ結線など**定義を触らない**経路向け：用法ごとに例文のみ生成する。
    /// - Parameters:
    ///   - headword: 画面・辞典の代表的見出し綴り（_allocate_ など）。プロンプトの辞書見出し行に使う。
    ///   - linkedLemmaStableId: セットされていれば辞典 `surfaces` から用量ごとの Embedding 綴り（_allocated_ など）を解決する。
    func generateExampleOnlyDraft(
        headword: String,
        linkedLemmaStableId: UUID?,
        slots: [VocabularyExampleDraftUsageSlot]
    ) async throws -> WordExampleDraft
    func lookupIPA(for headword: String) -> String?
}

// MARK: - Stub

struct StubVocabularyService: VocabularyService {
    nonisolated init() {}
    func save(_ vocabulary: CachedVocabulary) async throws {}
    func markDeleted(_ vocabulary: CachedVocabulary) async throws {}
    func fetchByRemoteId(_ remoteId: UUID) async throws -> CachedVocabulary? { nil }
    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws {}
    func bookmarkCandidate(_ candidate: VocabularyCandidate) async throws {}

    func generateWordDraft(
        headword: String,
        nativeLanguage: AuxiliaryLanguage,
        availableTags: [String]
    ) async throws -> WordDraft {
        WordDraft(usages: [], suggestedTags: [])
    }

    func generateExampleOnlyDraft(headword: String, linkedLemmaStableId: UUID?, slots: [VocabularyExampleDraftUsageSlot]) async throws -> WordExampleDraft {
        WordExampleDraft(groups: [])
    }

    func lookupIPA(for headword: String) -> String? { nil }
}

// MARK: - Live

struct LiveVocabularyService: VocabularyService {
    private let vocabularyRepository: any VocabularyRepository
    private let onDeviceWordDraftClient: any OnDeviceWordDraftClient
    private let onDeviceExampleDraftClient: any OnDeviceVocabularyExampleDraftClient
    private let pronunciationRepository: any PronunciationRepository
    private let lemmaLookupRepository: any LemmaLookupRepository

    init(
        vocabularyRepository: any VocabularyRepository,
        onDeviceWordDraftClient: any OnDeviceWordDraftClient,
        onDeviceExampleDraftClient: any OnDeviceVocabularyExampleDraftClient,
        pronunciationRepository: any PronunciationRepository,
        lemmaLookupRepository: any LemmaLookupRepository
    ) {
        self.vocabularyRepository = vocabularyRepository
        self.onDeviceWordDraftClient = onDeviceWordDraftClient
        self.onDeviceExampleDraftClient = onDeviceExampleDraftClient
        self.pronunciationRepository = pronunciationRepository
        self.lemmaLookupRepository = lemmaLookupRepository
    }

    func save(_ vocabulary: CachedVocabulary) async throws {
        try await vocabularyRepository.save(vocabulary)
    }

    func markDeleted(_ vocabulary: CachedVocabulary) async throws {
        try await vocabularyRepository.markDeleted(vocabulary)
    }

    func fetchByRemoteId(_ remoteId: UUID) async throws -> CachedVocabulary? {
        try await vocabularyRepository.fetchById(remoteId: remoteId)
    }

    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws {
        var sanitized = Self.payloadWithLemmaDefinitionsFromPack(
            payload,
            lemmaLookupRepository: lemmaLookupRepository
        )
        sanitized = Self.payloadWithFilledIPAWhenUnlinked(sanitized, pronunciationRepository: pronunciationRepository)
        try await vocabularyRepository.upsertAddForm(sanitized)
    }

    func bookmarkCandidate(_ candidate: VocabularyCandidate) async throws {
        let vocabulary = CachedVocabulary(
            headword: candidate.headword,
            source: VocabularySource.conversationCandidate.rawValue
        )
        let usage = CachedVocabularyUsage(kind: candidate.kind, position: 0)
        usage.definitionTarget = candidate.definitionTarget
        usage.definitionAux = candidate.definitionAux
        let head = candidate.headword.trimmingCharacters(in: .whitespacesAndNewlines)
        usage.studyHeadword = head.isEmpty ? nil : head
        usage.vocabulary = vocabulary
        try await vocabularyRepository.save(vocabulary)
    }

    func generateWordDraft(
        headword: String,
        nativeLanguage: AuxiliaryLanguage,
        availableTags: [String]
    ) async throws -> WordDraft {
        let trimmed = headword.trimmingCharacters(in: .whitespaces)
        let instructions = VocabularyWordDraftPrompt.systemInstructions(nativeLanguage: nativeLanguage)
        let prompt = VocabularyWordDraftPrompt.userPrompt(headword: trimmed, availableTags: availableTags)
        let raw = try await onDeviceWordDraftClient.respond(systemInstructions: instructions, userPrompt: prompt)
        return Self.normalizeWordDraft(raw)
    }

    func generateExampleOnlyDraft(headword: String, linkedLemmaStableId: UUID?, slots: [VocabularyExampleDraftUsageSlot]) async throws -> WordExampleDraft {
        let trimmed = headword.trimmingCharacters(in: .whitespaces)
        let resolved = slots.map { slot -> VocabularyWordExampleDraftPrompt.ResolvedExampleSlot in
            let embedding = Self.resolveEmbeddingSpelling(
                headline: trimmed,
                slot: slot,
                linkedLemmaStableId: linkedLemmaStableId,
                lemmaLookupRepository: lemmaLookupRepository
            )
            return VocabularyWordExampleDraftPrompt.ResolvedExampleSlot(slot: slot, embeddingSpelling: embedding)
        }
        let instructions = VocabularyWordExampleDraftPrompt.systemInstructions()
        let prompt = VocabularyWordExampleDraftPrompt.userPrompt(dictionaryLemmaHeadline: trimmed, resolvedSlots: resolved)
        let raw = try await onDeviceExampleDraftClient.respond(systemInstructions: instructions, userPrompt: prompt)
        return Self.normalizeExampleDraft(raw, expectedSlots: slots)
    }

    /// スロットの明示 `studyHeadword` →（空なら）辞典対応用法 → 画面見出し。
    private static func resolveEmbeddingSpelling(
        headline: String,
        slot: VocabularyExampleDraftUsageSlot,
        linkedLemmaStableId: UUID?,
        lemmaLookupRepository: any LemmaLookupRepository
    ) -> String {
        let trimmedHead = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlotStudy = slot.studyHeadword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSlotStudy.isEmpty {
            return trimmedSlotStudy
        }

        if let lemmaId = linkedLemmaStableId,
           let lemma = try? lemmaLookupRepository.fetchLemma(stableLemmaId: lemmaId),
           let embedding = LemmaStudyEmbeddingText.embeddingText(for: slot.kind, in: lemma)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !embedding.isEmpty {
            return embedding
        }
        return trimmedHead
    }

    /// モデル出力を単語帳ドメインとして解釈可能な形に絞る（無効な kind の用法は落とす）。
    private static func normalizeWordDraft(_ draft: WordDraft) -> WordDraft {
        WordDraft(
            usages: draft.usages.filter { VocabularyKind(rawValue: $0.kind) != nil }.map { usage in
                WordDraftUsage(
                    kind: usage.kind,
                    definitionTarget: usage.definitionTarget,
                    definitionAux: usage.definitionAux,
                    ipa: usage.ipa,
                    examples: usage.examples.map {
                        WordDraftExample(
                            sentenceTarget: VocabularyExampleSentenceSanitizer.strippingMarkdownBoldStars($0.sentenceTarget)
                        )
                    }
                )
            },
            suggestedTags: draft.suggestedTags
        )
    }

    private static func normalizeExampleDraft(_ draft: WordExampleDraft, expectedSlots: [VocabularyExampleDraftUsageSlot]) -> WordExampleDraft {
        let valid = draft.groups.filter { VocabularyKind(rawValue: $0.kind) != nil }
        let groups: [WordExampleDraftGroup] = expectedSlots.enumerated().map { index, slot in
            let kind = slot.kind
            if index < valid.count {
                let examples = valid[index].examples.map {
                    WordDraftExample(
                        sentenceTarget: VocabularyExampleSentenceSanitizer.strippingMarkdownBoldStars($0.sentenceTarget)
                    )
                }
                return WordExampleDraftGroup(kind: kind.rawValue, examples: examples)
            } else {
                return WordExampleDraftGroup(kind: kind.rawValue, examples: [])
            }
        }
        return WordExampleDraft(groups: groups)
    }

    /// レマ結線時は `CachedLemma` の定義を用法行に写す（ユーザー入力を上書きせず、常に辞典の正と一致させる）。
    private static func payloadWithLemmaDefinitionsFromPack(
        _ payload: VocabularyAddFormPayload,
        lemmaLookupRepository: any LemmaLookupRepository
    ) -> VocabularyAddFormPayload {
        guard let lid = payload.linkedLemmaStableId else { return payload }
        guard let lemma = try? lemmaLookupRepository.fetchLemma(stableLemmaId: lid) else { return payload }
        let lines = payload.usages.map { line in
            let pack = lemma.packUsageDefinitions(for: line.kind)
            return VocabularyAddFormUsageLine(
                kind: line.kind,
                ipa: line.ipa,
                definitionAux: pack.aux,
                definitionTarget: pack.target,
                studyHeadword: line.studyHeadword,
                examples: line.examples
            )
        }
        return VocabularyAddFormPayload(
            headword: payload.headword,
            usages: lines,
            selectedTagRemoteIds: payload.selectedTagRemoteIds,
            editingVocabularyRemoteId: payload.editingVocabularyRemoteId,
            linkedLemmaStableId: payload.linkedLemmaStableId,
            linkedAdjunctLemmaStableId: payload.linkedAdjunctLemmaStableId
        )
    }

    /// レマ未結線の手入力では IPA 入力欄を置かないため、未設定なら lookup で補う。
    private static func payloadWithFilledIPAWhenUnlinked(
        _ payload: VocabularyAddFormPayload,
        pronunciationRepository: any PronunciationRepository
    ) -> VocabularyAddFormPayload {
        guard payload.linkedLemmaStableId == nil else { return payload }
        let word = payload.headword.trimmingCharacters(in: .whitespaces)
        let ipa = pronunciationRepository.lookupIPA(for: word) ?? ""
        guard !ipa.isEmpty else { return payload }
        let lines = payload.usages.map { line in
            var next = line
            if next.ipa.trimmingCharacters(in: .whitespaces).isEmpty {
                next.ipa = ipa
            }
            return next
        }
        return VocabularyAddFormPayload(
            headword: payload.headword,
            usages: lines,
            selectedTagRemoteIds: payload.selectedTagRemoteIds,
            editingVocabularyRemoteId: payload.editingVocabularyRemoteId,
            linkedLemmaStableId: payload.linkedLemmaStableId,
            linkedAdjunctLemmaStableId: payload.linkedAdjunctLemmaStableId
        )
    }

    func lookupIPA(for headword: String) -> String? {
        pronunciationRepository.lookupIPA(for: headword)
    }
}
