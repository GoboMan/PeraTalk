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
