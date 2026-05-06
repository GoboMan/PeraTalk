import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class VocabularyAddScreenModel {
    var headword: String = ""
    var usages: [UsageFormData] = []
    var selectedTagIds: Set<UUID> = []
    /// プリセット辞典から選んだレマ（保存時 `CachedVocabulary.lemma` に結線）。
    var linkedLemmaStableId: UUID?
    var linkedAdjunctLemmaStableId: UUID?
    /// 辞典に載っていない語として、すべて手入力のフォームへ進んだ。
    var useManualDictionaryBypass: Bool = false
    var lemmaSearchCandidates: [LemmaSearchCandidate] = []
    /// 見出し語のデバウンス後に辞典検索が走るまで（誤って「候補なし」UIを出さないため）。
    private(set) var isLemmaLookupPending = false

    private(set) var editingVocabularyId: UUID?
    var isGenerating: Bool = false
    /// 見出し語の全文 AI と排他。例文 1 件の生成中は該当例文の UUID。
    var generatingExampleId: UUID?
    var generationError: String?

    private let generateDraftUseCase: GenerateVocabularyAddFormDraftUseCase
    private let generateExampleDraftUseCase: GenerateVocabularyExampleDraftUseCase
    private let loadEditingUseCase: LoadVocabularyAddFormForEditingUseCase
    private let saveFormUseCase: SaveVocabularyAddFormUseCase
    private let searchLemmaCandidatesUseCase: SearchLemmaCandidatesForVocabularyAddUseCase
    private let seedFromLemmaUseCase: SeedVocabularyAddFormFromLemmaUseCase

    private var lemmaLookupDebounceTask: Task<Void, Never>?
    /// `scheduleLemmaCandidateRefresh` のたびに増やし、直近の検索だけが `isLemmaLookupPending` を下げる。
    private var lemmaLookupEpoch: UInt64 = 0

    init(
        generateDraftUseCase: GenerateVocabularyAddFormDraftUseCase = GenerateVocabularyAddFormDraftUseCase(
            vocabularyService: StubVocabularyService()
        ),
        generateExampleDraftUseCase: GenerateVocabularyExampleDraftUseCase = GenerateVocabularyExampleDraftUseCase(
            vocabularyService: StubVocabularyService()
        ),
        loadEditingUseCase: LoadVocabularyAddFormForEditingUseCase = LoadVocabularyAddFormForEditingUseCase(
            vocabularyService: StubVocabularyService()
        ),
        saveFormUseCase: SaveVocabularyAddFormUseCase = SaveVocabularyAddFormUseCase(vocabularyService: StubVocabularyService()),
        searchLemmaCandidatesUseCase: SearchLemmaCandidatesForVocabularyAddUseCase = SearchLemmaCandidatesForVocabularyAddUseCase(
            lemmaLookupRepository: StubLemmaLookupRepository()
        ),
        seedFromLemmaUseCase: SeedVocabularyAddFormFromLemmaUseCase = SeedVocabularyAddFormFromLemmaUseCase(
            lemmaLookupRepository: StubLemmaLookupRepository()
        )
    ) {
        self.generateDraftUseCase = generateDraftUseCase
        self.generateExampleDraftUseCase = generateExampleDraftUseCase
        self.loadEditingUseCase = loadEditingUseCase
        self.saveFormUseCase = saveFormUseCase
        self.searchLemmaCandidatesUseCase = searchLemmaCandidatesUseCase
        self.seedFromLemmaUseCase = seedFromLemmaUseCase
    }

    /// SwiftData を使う実行時構成。プレビュー以外ではこちらを優先する。
    static func live(modelContext: ModelContext) -> VocabularyAddScreenModel {
        let repository = SwiftDataVocabularyRepository(context: modelContext)
        let lemmaLookup = SwiftDataLemmaLookupRepository(context: modelContext)
        let wordClient = FoundationModelsWordDraftClient()
        let exampleClient = FoundationModelsVocabularyExampleDraftClient()
        let service = LiveVocabularyService(
            vocabularyRepository: repository,
            onDeviceWordDraftClient: wordClient,
            onDeviceExampleDraftClient: exampleClient,
            pronunciationRepository: CMUDictPronunciationRepository(),
            lemmaLookupRepository: lemmaLookup
        )
        return VocabularyAddScreenModel(
            generateDraftUseCase: GenerateVocabularyAddFormDraftUseCase(vocabularyService: service),
            generateExampleDraftUseCase: GenerateVocabularyExampleDraftUseCase(vocabularyService: service),
            loadEditingUseCase: LoadVocabularyAddFormForEditingUseCase(vocabularyService: service),
            saveFormUseCase: SaveVocabularyAddFormUseCase(vocabularyService: service),
            searchLemmaCandidatesUseCase: SearchLemmaCandidatesForVocabularyAddUseCase(
                lemmaLookupRepository: lemmaLookup
            ),
            seedFromLemmaUseCase: SeedVocabularyAddFormFromLemmaUseCase(lemmaLookupRepository: lemmaLookup)
        )
    }

    var isEditing: Bool { editingVocabularyId != nil }

    var registrationMode: VocabularyAddRegistrationMode {
        if isEditing { return .editing }
        if useManualDictionaryBypass { return .custom }
        if linkedLemmaStableId != nil { return .lemmaLinked }
        return .pickingLemma
    }

    /// プリセットレマに結線しており、定義をユーザー／全文 AI で上書きしない。
    var isLemmaDefinitionLocked: Bool { linkedLemmaStableId != nil }

    /// 編集済みコンテンツ（用法・発音 AI・タグ）を一覧する。
    var showDetailedEditor: Bool {
        isEditing || useManualDictionaryBypass || linkedLemmaStableId != nil
    }

    /// 見出し語右側の全文「AI生成」。レマ結線時は不可。
    var allowsFullWordAIDraft: Bool {
        switch registrationMode {
        case .lemmaLinked, .pickingLemma:
            return false
        case .custom:
            return true
        case .editing:
            return !isLemmaDefinitionLocked
        }
    }

    /// 新規のみ：辞典から候補を探すフェーズ。
    var showLemmaSearchFlow: Bool {
        !isEditing
    }

    var canSave: Bool {
        !headword.trimmingCharacters(in: .whitespaces).isEmpty && !usages.isEmpty
    }

    var availableKinds: [VocabularyKind] {
        let usedKinds = Set(usages.map(\.kind))
        return VocabularyKind.allCases.filter { !usedKinds.contains($0) }
    }

    func applyEditingPayload(_ payload: VocabularyAddFormPayload) {
        editingVocabularyId = payload.editingVocabularyRemoteId
        headword = payload.headword
        usages = Self.usageFormData(from: payload.usages)
        selectedTagIds = payload.selectedTagRemoteIds
        linkedLemmaStableId = payload.linkedLemmaStableId
        linkedAdjunctLemmaStableId = payload.linkedAdjunctLemmaStableId
        useManualDictionaryBypass = false
        lemmaSearchCandidates = []
        isLemmaLookupPending = false
    }

    func makePayload() -> VocabularyAddFormPayload {
        VocabularyAddFormPayload(
            headword: headword.trimmingCharacters(in: .whitespaces),
            usages: Self.usageLines(from: usages),
            selectedTagRemoteIds: selectedTagIds,
            editingVocabularyRemoteId: editingVocabularyId,
            linkedLemmaStableId: linkedLemmaStableId,
            linkedAdjunctLemmaStableId: linkedAdjunctLemmaStableId
        )
    }

    func loadForEditing(remoteId: UUID) async throws {
        guard let payload = try await loadEditingUseCase.execute(remoteId: remoteId) else { return }
        applyEditingPayload(payload)
    }

    func saveForm() async throws {
        try await saveFormUseCase.execute(makePayload())
    }

    func scheduleLemmaCandidateRefresh() {
        lemmaLookupDebounceTask?.cancel()
        let query = headword.trimmingCharacters(in: .whitespaces)

        guard showLemmaSearchFlow, !useManualDictionaryBypass, linkedLemmaStableId == nil else {
            lemmaSearchCandidates = []
            isLemmaLookupPending = false
            return
        }

        if query.isEmpty {
            lemmaSearchCandidates = []
            isLemmaLookupPending = false
            lemmaLookupEpoch += 1
            return
        }

        lemmaLookupEpoch += 1
        let epoch = lemmaLookupEpoch
        isLemmaLookupPending = true
        lemmaLookupDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await refreshLemmaCandidatesIfNeeded(trimmedQuery: query)
            guard !Task.isCancelled, epoch == lemmaLookupEpoch else { return }
            isLemmaLookupPending = false
        }
    }

    private func refreshLemmaCandidatesIfNeeded(trimmedQuery: String) async {
        guard showLemmaSearchFlow, !useManualDictionaryBypass, linkedLemmaStableId == nil else {
            lemmaSearchCandidates = []
            return
        }
        guard !trimmedQuery.isEmpty else {
            lemmaSearchCandidates = []
            return
        }
        do {
            lemmaSearchCandidates = try searchLemmaCandidatesUseCase.execute(trimmedHeadwordPrefix: trimmedQuery)
        } catch {
            lemmaSearchCandidates = []
        }
    }

    /// ユーザーが辞典候補を選んだとき：品詞・IPA 枠のみレマから流し込み（定義・例文は空 → AI）。
    func selectLemmaCandidate(_ candidate: LemmaSearchCandidate) async {
        generationError = nil
        do {
            let seed = try seedFromLemmaUseCase.execute(stableLemmaId: candidate.stableLemmaId)
            linkedLemmaStableId = candidate.stableLemmaId
            linkedAdjunctLemmaStableId = nil
            headword = seed.suggestedHeadword
            usages = Self.usageFormData(from: seed.usageLines)
            useManualDictionaryBypass = false
            lemmaSearchCandidates = []
            isLemmaLookupPending = false
        } catch {
            generationError = error.localizedDescription
        }
    }

    /// 辞典から別の語を選び直す（新規のみ）。
    func beginReselectingLemma() {
        guard !isEditing else { return }
        linkedLemmaStableId = nil
        linkedAdjunctLemmaStableId = nil
        usages = []
        lemmaSearchCandidates = []
        isLemmaLookupPending = false
        scheduleLemmaCandidateRefresh()
    }

    /// 辞典に無い語としてこれまでどおりすべて手入力。
    func activateManualDictionaryEntry() {
        guard !isEditing else { return }
        useManualDictionaryBypass = true
        linkedLemmaStableId = nil
        linkedAdjunctLemmaStableId = nil
        lemmaSearchCandidates = []
        isLemmaLookupPending = false
        let usage = UsageFormData(kind: .noun)
        usages = [usage]
    }

    func addUsage(kind: VocabularyKind) {
        guard !isLemmaDefinitionLocked else { return }
        let usage = UsageFormData(kind: kind)
        usages.append(usage)
    }

    func removeUsage(_ usageId: UUID) {
        guard !isLemmaDefinitionLocked else { return }
        usages.removeAll { $0.id == usageId }
    }

    func addExample(to usageId: UUID) {
        guard let index = usages.firstIndex(where: { $0.id == usageId }) else { return }
        usages[index].examples.append(ExampleFormData())
    }

    func removeExample(from usageId: UUID, exampleId: UUID) {
        guard let index = usages.firstIndex(where: { $0.id == usageId }) else { return }
        usages[index].examples.removeAll { $0.id == exampleId }
    }

    func toggleTag(_ tagId: UUID) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
    }

    func generateDraft(tagItems: [TagPickerItem], nativeLanguage: AuxiliaryLanguage) async {
        guard allowsFullWordAIDraft else { return }
        guard generatingExampleId == nil else { return }
        let word = headword.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }

        isGenerating = true
        generationError = nil
        defer { isGenerating = false }

        do {
            let payload = try await generateDraftUseCase.execute(
                headword: headword,
                nativeLanguage: nativeLanguage,
                tags: tagItems
            )
            applyAIDraft(payload)
        } catch {
            generationError = error.localizedDescription
        }
    }

    /// 1 つの例文欄のみオンデバイス生成で埋める。
    func generateExampleSentence(usageId: UUID, exampleId: UUID) async {
        guard generatingExampleId == nil else { return }
        guard !isGenerating else { return }
        let word = headword.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty,
              let usageIndex = usages.firstIndex(where: { $0.id == usageId }),
              let exampleIndex = usages[usageIndex].examples.firstIndex(where: { $0.id == exampleId })
        else { return }

        let kind = usages[usageIndex].kind

        generatingExampleId = exampleId
        generationError = nil
        defer { generatingExampleId = nil }

        do {
            guard let sentence = try await generateExampleDraftUseCase.firstExampleSentence(headword: word, usageKind: kind) else {
                generationError = "例文を生成できませんでした"
                return
            }
            usages[usageIndex].examples[exampleIndex].sentence = sentence
        } catch {
            generationError = error.localizedDescription
        }
    }

    private func applyAIDraft(_ payload: VocabularyAddFormPayload) {
        let keepLemma = linkedLemmaStableId
        let keepAdjunct = linkedAdjunctLemmaStableId

        headword = payload.headword
        usages = Self.usageFormData(from: payload.usages)
        selectedTagIds = payload.selectedTagRemoteIds

        linkedLemmaStableId = keepLemma
        linkedAdjunctLemmaStableId = keepAdjunct
    }

    private static func usageLines(from usages: [UsageFormData]) -> [VocabularyAddFormUsageLine] {
        usages.map { usage in
            VocabularyAddFormUsageLine(
                kind: usage.kind,
                ipa: usage.ipa,
                definitionAux: usage.definitionAux,
                definitionTarget: usage.definitionTarget,
                examples: usage.examples.map {
                    VocabularyAddFormExampleLine(sentence: $0.sentence)
                }
            )
        }
    }

    private static func usageFormData(from lines: [VocabularyAddFormUsageLine]) -> [UsageFormData] {
        lines.map { line in
            let examples = line.examples.map {
                ExampleFormData(sentence: $0.sentence)
            }
            return UsageFormData(
                kind: line.kind,
                ipa: line.ipa,
                definitionAux: line.definitionAux,
                definitionTarget: line.definitionTarget,
                examples: examples.isEmpty ? [ExampleFormData()] : examples
            )
        }
    }
}
