import SwiftUI
import SwiftData
import Translation
import UIKit

struct VocabularyDetailScreen: View {
    @Query private var vocabularies: [CachedVocabulary]
    @Query private var profiles: [CachedProfile]
    @Binding var path: NavigationPath
    @State private var translations: [UUID: String] = [:]
    @State private var exampleTranslationPendingIds: Set<UUID> = []
    /// 翻訳ターゲット言語が確定するまで Translation のタスクを付けない（セッションの再生成・シートちらつきを防ぐ）。
    @State private var translationTargetAuxiliary: AuxiliaryLanguage?
    /// 「意味を伏せるモード」時のみ、この単語ページでオーバーレイを外した状態かどうか（単語・画面ごとにリセット）。
    @State private var recallObfuscationContentRevealed = false
    private let vocabularyId: UUID
    /// `false` のときはツールバーを出さない（`VocabularyDetailPagerScreen` が親で 1 つだけ表示する）。
    private let embedsNavigationChrome: Bool
    /// `true` のとき見出し以外をマテリアルで伏せ、タップでこのページだけ解除できる。
    private let recallObfuscationModeEnabled: Bool
    /// ペジャーで現在表示中の単語 ID。フォーカスがこの画面に戻るたびに伏せ状態へ戻す。単独詳細では `nil`。
    private let pagerFocusedVocabularyId: UUID?

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

    init(
        vocabularyId: UUID,
        path: Binding<NavigationPath>,
        embedsNavigationChrome: Bool = true,
        recallObfuscationModeEnabled: Bool = false,
        pagerFocusedVocabularyId: UUID? = nil
    ) {
        self.vocabularyId = vocabularyId
        self.embedsNavigationChrome = embedsNavigationChrome
        self.recallObfuscationModeEnabled = recallObfuscationModeEnabled
        self.pagerFocusedVocabularyId = pagerFocusedVocabularyId
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
        let core = Group {
            if let vocabulary {
                exampleTranslationWrappedContent(for: vocabulary)
            } else {
                ContentUnavailableView("単語が見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
        .task(id: "\(vocabularyId.uuidString)-\(auxiliaryLanguageKey)") {
            translations.removeAll(keepingCapacity: true)
            exampleTranslationPendingIds = []
            translationTargetAuxiliary = auxiliaryForExamples
        }
        .onChange(of: vocabularyId) { _, _ in
            resetRecallPracticeOverlayWithoutAnimation()
        }
        .onChange(of: recallObfuscationModeEnabled) { _, enabled in
            if enabled {
                resetRecallPracticeOverlayWithoutAnimation()
            }
        }
        /// ペジャーの表示単語が変わったら、**すべてのページ**で伏せを即復帰（離れたページがタップ解除のまま残るとスワイプ中にチラつく）。
        .onChange(of: pagerFocusedVocabularyId) { _, _ in
            guard recallObfuscationModeEnabled else { return }
            resetRecallPracticeOverlayWithoutAnimation()
        }

        if embedsNavigationChrome {
            core
                .navigationTitle("Vocabulary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        VocabularyDetailTrailingMenu(
                            path: $path,
                            vocabularyRemoteId: vocabularyId,
                            recallObfuscationModeEnabled: nil
                        )
                    }
                }
        } else {
            core
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
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 20) {
                        tagSection(vocabulary)
                        usagesSection(vocabulary)
                        etymologySection(vocabulary)
                    }
                    if recallObfuscationModeEnabled {
                        recallPracticeGlassOverlay
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    /// タップ解除時のみアニメーション。ページ切り替え等では `resetRecallPracticeOverlayWithoutAnimation()` で瞬時に伏せる。
    private func resetRecallPracticeOverlayWithoutAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            recallObfuscationContentRevealed = false
        }
    }

    private var recallPracticeGlassOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.clear)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            /// Liquid Glass（明るいガラス）。グレーのヴェールではなく、ガラス越しに文字が柔らかく霞む見え方。
            .glassEffect(
                .regular.tint(Color.white.opacity(0.34)),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                /// ガラス表面のハイライト（グレーではなく明るい折射のニュアンス）。
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.22, y: 0.12),
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                Text("タップして表示")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(Color.white.opacity(0.2)), in: Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                    /// タップはガラス全面で受ける（チップだけが反応しないようにする）。
                    .allowsHitTesting(false)
            }
            .compositingGroup()
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(recallObfuscationContentRevealed ? 0 : 1)
            .blur(radius: recallObfuscationContentRevealed ? 10 : 0)
            .scaleEffect(recallObfuscationContentRevealed ? 0.94 : 1, anchor: .center)
            .allowsHitTesting(!recallObfuscationContentRevealed)
            .accessibilityAddTraits(.isButton)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("詳細を表示")
            .accessibilityHint("意味を伏せるモード中です。タップするとこの単語の詳細が読めます。")
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.easeOut(duration: 0.52)) {
                    recallObfuscationContentRevealed = true
                }
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

    private func usagesSection(_ vocabulary: CachedVocabulary) -> some View {
        let activeUsages = vocabulary.usages
            .filter { !$0.tombstone }
            .sorted { $0.position < $1.position }

        return VStack(spacing: 16) {
            ForEach(activeUsages, id: \.remoteId) { usage in
                UsageCardView(
                    kind: usage.kind,
                    ipa: usage.ipa,
                    definitionAux: vocabulary.resolvedDefinitionAux(for: usage),
                    definitionTarget: vocabulary.resolvedDefinitionTarget(for: usage),
                    examples: usage.examples,
                    lemmaInflectionUsage: lemmaInflectionUsage(matching: usage, in: vocabulary),
                    translations: translations,
                    pendingExampleTranslationIds: exampleTranslationPendingIds,
                    exampleTranslationLineTitle: shouldTranslateExampleSentences ? translationTargetAuxiliary?.translationLabel : nil
                )
            }
        }
    }

    /// `CachedVocabularyUsage.kind` に一致し、活用行がある辞典用法を返す（主レマ→補助レマ）。
    private func lemmaInflectionUsage(matching vocabularyUsage: CachedVocabularyUsage, in vocabulary: CachedVocabulary) -> CachedLemmaUsage? {
        func pick(from lemma: CachedLemma?) -> CachedLemmaUsage? {
            guard let lemma else { return nil }
            guard let u = lemma.usages.first(where: { $0.kind == vocabularyUsage.kind }) else { return nil }
            return LemmaParadigmPresenter.usageHasInflectionRows(u) ? u : nil
        }
        return pick(from: vocabulary.lemma) ?? pick(from: vocabulary.adjunctLemma)
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

}

#Preview {
    @Previewable @State var path = NavigationPath()
    @Previewable @State var vocabularyRecallObfuscationModeEnabled = false
    let id = previewAllocateVocabulary.remoteId
    NavigationStack(path: $path) {
        VocabularyDetailPagerScreen(
            sequence: [id],
            currentId: id,
            path: $path,
            recallObfuscationModeEnabled: $vocabularyRecallObfuscationModeEnabled
        )
            .navigationDestination(for: VocabularyRoute.self) { route in
                switch route {
                case .edit(let editId):
                    VocabularyAddScreen(vocabularyId: editId)
                default:
                    EmptyView()
                }
            }
    }
    .modelContainer(previewContainer)
}
