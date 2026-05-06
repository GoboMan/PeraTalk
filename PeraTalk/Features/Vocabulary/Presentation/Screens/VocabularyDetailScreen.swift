import SwiftUI
import SwiftData
import Translation

struct VocabularyDetailScreen: View {
    @Query private var vocabularies: [CachedVocabulary]
    @Query private var profiles: [CachedProfile]
    @Binding var path: NavigationPath
    @State private var translations: [UUID: String] = [:]
    @State private var exampleTranslationPendingIds: Set<UUID> = []
    /// 翻訳ターゲット言語が確定するまで Translation のタスクを付けない（セッションの再生成・シートちらつきを防ぐ）。
    @State private var translationTargetAuxiliary: AuxiliaryLanguage?
    private let vocabularyId: UUID

    /// 一覧と同じソースのクエリ順序に依存しないよう、詳細だけ補助言語キーを task id に含める。
    private var auxiliaryLanguageKey: String {
        profiles.first?.auxiliaryLanguage ?? ""
    }

    private var auxiliaryForExamples: AuxiliaryLanguage {
        profiles.first.flatMap { AuxiliaryLanguage(rawValue: $0.auxiliaryLanguage) }
            ?? .systemDefault
    }

    /// 見出し例文が英語想定で、ユーザーの母語などへ訳す。補助言語が英語のときは原文と重複しないよう翻訳しない。
    private var shouldTranslateExampleSentences: Bool {
        translationTargetAuxiliary.map { $0 != .english } ?? false
    }

    private func shouldAttachExampleTranslationPipeline(for vocabulary: CachedVocabulary?) -> Bool {
        guard vocabulary != nil else { return false }
        guard shouldTranslateExampleSentences else { return false }
        return !allActiveExamples.isEmpty
    }

    init(vocabularyId: UUID, path: Binding<NavigationPath>) {
        self.vocabularyId = vocabularyId
        self._path = path
        _vocabularies = Query(filter: #Predicate<CachedVocabulary> {
            $0.remoteId == vocabularyId
        })
    }

    private var vocabulary: CachedVocabulary? {
        vocabularies.first
    }

    private var allActiveExamples: [CachedVocabularyExample] {
        guard let vocabulary else { return [] }
        return vocabulary.usages
            .filter { !$0.tombstone }
            .flatMap { $0.examples.filter { !$0.tombstone } }
    }

    var body: some View {
        Group {
            if let vocabulary {
                exampleTranslationWrappedContent(for: vocabulary)
            } else {
                ContentUnavailableView("単語が見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .task(id: "\(vocabularyId.uuidString)-\(auxiliaryLanguageKey)") {
            translations.removeAll(keepingCapacity: true)
            exampleTranslationPendingIds = []
            translationTargetAuxiliary = auxiliaryForExamples
        }
    }

    @ViewBuilder
    private func exampleTranslationWrappedContent(for vocabulary: CachedVocabulary) -> some View {
        let content = contentView(vocabulary)
        if shouldAttachExampleTranslationPipeline(for: vocabulary),
           let targetAuxiliary = translationTargetAuxiliary {
            content
                .translationTask(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: targetAuxiliary.rawValue)
                ) { session in
                    await translateExamples(using: session)
                }
        } else {
            content
        }
    }

    private func translateExamples(using session: TranslationSession) async {
        let examples = allActiveExamples.filter {
            !$0.sentenceTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !examples.isEmpty else {
            await MainActor.run {
                exampleTranslationPendingIds = []
            }
            return
        }

        await MainActor.run {
            exampleTranslationPendingIds = Set(examples.map(\.remoteId))
        }

        let requests = examples.map {
            TranslationSession.Request(
                sourceText: $0.sentenceTarget,
                clientIdentifier: $0.remoteId.uuidString
            )
        }

        do {
            let responses = try await session.translations(from: requests)
            await MainActor.run {
                for response in responses {
                    if let idString = response.clientIdentifier,
                       let uuid = UUID(uuidString: idString) {
                        translations[uuid] = response.targetText
                    }
                }
                exampleTranslationPendingIds = []
            }
        } catch {
            await MainActor.run {
                exampleTranslationPendingIds = []
            }
        }
    }

    private func contentView(_ vocabulary: CachedVocabulary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headwordSection(vocabulary)
                tagSection(vocabulary)
                usagesSection(vocabulary)
                lemmaInflectionSections(vocabulary)
                etymologySection(vocabulary)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Headword

    private func headwordSection(_ vocabulary: CachedVocabulary) -> some View {
        Text(vocabulary.headword)
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    // MARK: - Tags

    @ViewBuilder
    private func tagSection(_ vocabulary: CachedVocabulary) -> some View {
        let activeTags = vocabulary.vocabularyTagLinks
            .filter { !$0.tombstone }
            .compactMap { $0.tag }
            .filter { !$0.tombstone }

        if !activeTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeTags, id: \.remoteId) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(.blue)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Usages

    private func resolvedDefinitionAux(vocabulary: CachedVocabulary, usage: CachedVocabularyUsage) -> String? {
        let fromUsage = usage.definitionAux?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromUsage.isEmpty { return usage.definitionAux }
        if let lemma = vocabulary.lemma, let kind = VocabularyKind(rawValue: usage.kind) {
            let pack = lemma.packUsageDefinitions(for: kind)
            let packAux = pack.aux.trimmingCharacters(in: .whitespacesAndNewlines)
            if !packAux.isEmpty { return pack.aux }
        }
        return usage.definitionAux
    }

    private func resolvedDefinitionTarget(vocabulary: CachedVocabulary, usage: CachedVocabularyUsage) -> String? {
        let fromUsage = usage.definitionTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromUsage.isEmpty { return usage.definitionTarget }
        if let lemma = vocabulary.lemma, let kind = VocabularyKind(rawValue: usage.kind) {
            let pack = lemma.packUsageDefinitions(for: kind)
            let packTarget = pack.target.trimmingCharacters(in: .whitespacesAndNewlines)
            if !packTarget.isEmpty { return pack.target }
        }
        return usage.definitionTarget
    }

    private func usagesSection(_ vocabulary: CachedVocabulary) -> some View {
        let activeUsages = vocabulary.usages
            .filter { !$0.tombstone }
            .sorted { $0.position < $1.position }

        return VStack(spacing: 16) {
            ForEach(activeUsages, id: \.remoteId) { usage in
                UsageCardView(
                    kind: usage.kind,
                    ipa: usage.ipa,
                    definitionAux: resolvedDefinitionAux(vocabulary: vocabulary, usage: usage),
                    definitionTarget: resolvedDefinitionTarget(vocabulary: vocabulary, usage: usage),
                    examples: usage.examples,
                    translations: translations,
                    pendingExampleTranslationIds: exampleTranslationPendingIds,
                    exampleTranslationLineTitle: shouldTranslateExampleSentences ? translationTargetAuxiliary?.translationLabel : nil
                )
            }
        }
    }

    // MARK: - Lemma inflection

    /// 動詞／形容詞の辞典レマがあれば、表面形ごとに活用を表示する（同一レマに `verb_*` と `adj_*` が両方あれば二表を出す）。
    @ViewBuilder
    private func lemmaInflectionSections(_ vocabulary: CachedVocabulary) -> some View {
        if let lemma = vocabulary.lemma, LemmaParadigmPresenter.lemmaHasInflectionRows(lemma) {
            ForEach(Array(LemmaParadigmPresenter.ParadigmColumn.allCases), id: \.self) { column in
                LemmaInflectionSectionView(lemma: lemma, column: column)
            }
        }
        if let adjunct = vocabulary.adjunctLemma, LemmaParadigmPresenter.lemmaHasInflectionRows(adjunct) {
            ForEach(Array(LemmaParadigmPresenter.ParadigmColumn.allCases), id: \.self) { column in
                LemmaInflectionSectionView(lemma: adjunct, column: column)
            }
        }
    }

    // MARK: - Etymology

    @ViewBuilder
    private func etymologySection(_ vocabulary: CachedVocabulary) -> some View {
        if let notes = vocabulary.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Etymology")
                    .font(.headline)
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - More Menu

    private var moreMenu: some View {
        Menu {
            Button {
                path.append(VocabularyRoute.edit(vocabularyId))
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                // TODO: 削除処理
            } label: {
                Label("削除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        VocabularyDetailScreen(vocabularyId: previewAllocateVocabulary.remoteId, path: $path)
            .navigationDestination(for: VocabularyRoute.self) { route in
                switch route {
                case .edit(let id):
                    VocabularyAddScreen(vocabularyId: id)
                default:
                    EmptyView()
                }
            }
    }
    .modelContainer(previewContainer)
}
