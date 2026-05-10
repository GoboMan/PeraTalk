import SwiftUI
import SwiftData
import Translation

struct VocabularyAddScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CachedTag> { !$0.tombstone },
           sort: \CachedTag.name)
    private var tags: [CachedTag]
    @Query private var profiles: [CachedProfile]

    @State private var model: VocabularyAddScreenModel?

    private let editVocabularyId: UUID?
    private let preselectedTagId: UUID?

    private var nativeLanguage: AuxiliaryLanguage {
        guard let raw = profiles.first?.auxiliaryLanguage else { return .systemDefault }
        return AuxiliaryLanguage(rawValue: raw) ?? .japanese
    }

    init(vocabularyId: UUID? = nil, preselectedTagId: UUID? = nil) {
        self.editVocabularyId = vocabularyId
        self.preselectedTagId = vocabularyId == nil ? preselectedTagId : nil
    }

    var body: some View {
        Group {
            if let model {
                VocabularyAddLoadedContent(model: model, tags: tags, nativeLanguage: nativeLanguage)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                let m = VocabularyAddScreenModel.live(modelContext: modelContext)
                if let preselectedTagId {
                    m.selectedTagIds.insert(preselectedTagId)
                }
                model = m
            }
            guard let editVocabularyId, let m = model else { return }
            if !m.isEditing {
                try? await m.loadForEditing(remoteId: editVocabularyId)
            }
        }
    }
}

// MARK: - Loaded content (@Bindable)

private struct VocabularyAddLoadedContent: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: VocabularyAddScreenModel
    let tags: [CachedTag]
    let nativeLanguage: AuxiliaryLanguage

    @State private var exampleTranslations: [UUID: String] = [:]
    /// 最後に翻訳が本文と一致していた例文（文が変わった ID だけ訳を落とし、他はそのまま表示）。
    @State private var lastTranslatedSentenceByExampleId: [UUID: String] = [:]

    /// 辞典レマ選び済みで戻ったとき、ナビゲーションバー横並びで「やめる／選び直す」を表示する。
    @State private var lemmaLinkedBackChoicesExpanded = false

    /// 新規かつ辞典レマ結線済みのとき、戻るで上記選択を出す。
    private var showsLemmaLinkedBackChoices: Bool {
        !model.isEditing && model.linkedLemmaStableId != nil && !model.useManualDictionaryBypass
    }

    /// 例文が英語想定で、補助言語へ訳す（英語設定時は原文と重複しないよう付けない）。
    private var shouldTranslateExampleSentences: Bool {
        nativeLanguage != .english
    }

    private func shouldAttachExampleTranslationPipeline() -> Bool {
        // 手入力の一文目が入る前からセッションを温め、キー入力直後に翻訳が走りやすくする。
        shouldTranslateExampleSentences && model.showDetailedEditor
    }

    private static func formExamplesTranslationDigest(usages: [UsageFormData], language: AuxiliaryLanguage) -> String {
        language.rawValue + "|" + usages.flatMap(\.examples).map { "\($0.id.uuidString):\($0.sentence)" }
            .joined(separator: "\u{1e}")
    }

    var body: some View {
        exampleTranslationWrappedRoot
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if lemmaLinkedBackChoicesExpanded, showsLemmaLinkedBackChoices {
                    Button {
                        lemmaLinkedBackChoicesExpanded = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("選択を閉じる")

                    Button("単語追加をやめる") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)

                    Button("辞典から選び直す") {
                        model.beginReselectingLemma()
                        lemmaLinkedBackChoicesExpanded = false
                    }
                    .font(.subheadline)
                } else {
                    Button {
                        if showsLemmaLinkedBackChoices {
                            lemmaLinkedBackChoicesExpanded = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("戻る")
                }
            }
        }
        .onChange(of: model.linkedLemmaStableId) { _, newId in
            if newId == nil {
                lemmaLinkedBackChoicesExpanded = false
            }
        }
        .onChange(of: model.isEditing) { _, nowEditing in
            if nowEditing {
                lemmaLinkedBackChoicesExpanded = false
            }
        }
        .alert("AI生成エラー", isPresented: Binding(
            get: { model.generationError != nil },
            set: { if !$0 { model.generationError = nil } }
        )) {
            Button("OK") { model.generationError = nil }
        } message: {
            if let error = model.generationError {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private var exampleTranslationWrappedRoot: some View {
        let stack = List {
            Section {
                headwordSection
            }

            lemmaSearchSectionIfNeeded()

            detailedEditorSectionsIfNeeded()
        }
        .listStyle(.insetGrouped)
        /// 連続した行で「品詞／定義」と例文エリアが一枚のカードに見えるよう行間隙間をなくす。
        .listRowSpacing(0)
        .scrollContentBackground(.visible)
        .onChange(of: model.headword) { _, _ in
            model.scheduleLemmaCandidateRefresh()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveButton
        }

        if shouldAttachExampleTranslationPipeline() {
            stack
                .translationTask(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: nativeLanguage.rawValue)
                ) { session in
                    await runFormExampleTranslationLoop(using: session)
                }
        } else {
            stack
        }
    }

    @ViewBuilder
    private func lemmaSearchSectionIfNeeded() -> some View {
        if model.showLemmaSearchFlow,
           !model.useManualDictionaryBypass,
           model.linkedLemmaStableId == nil,
           !model.headword.trimmingCharacters(in: .whitespaces).isEmpty {
            Section {
                lemmaCandidateSearchSectionBody
            }
        }
    }

    /// `headword` 非空は `lemmaSearchSectionIfNeeded` で保証済み。
    @ViewBuilder
    private var lemmaCandidateSearchSectionBody: some View {
        if model.isLemmaLookupPending {
            HStack(spacing: 8) {
                ProgressView()
                Text("辞典を検索中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else if model.lemmaSearchCandidates.isEmpty {
            manualDictionaryEntryButton
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("辞典から選ぶ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(model.lemmaSearchCandidates) { candidate in
                        Button {
                            Task { await model.selectLemmaCandidate(candidate) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(candidate.lemmaText)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 8)
                                    if let kind = VocabularyKind(rawValue: candidate.posRaw)
                                        ?? VocabularyKind(kindString: candidate.posRaw) {
                                        VocabularyPartOfSpeechCapsuleChip(kind: kind)
                                    }
                                }
                                if let summary = candidate.multiKindSummary {
                                    Text(summary)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailedEditorSectionsIfNeeded() -> some View {
        if model.showDetailedEditor {
            ForEach(model.usages) { usage in
                let usageId = usage.id
                let removeTailRowCount = model.isLemmaDefinitionLocked ? 0 : 1

                Section {
                    usageDefinitionListRow(usageId: usageId)
                        .listRowInsets(UsageExamplesSectionChrome.definitionRowInsets)
                        .listRowSeparator(.hidden, edges: .bottom)
                        .listRowBackground(UsageExamplesSectionChrome.definitionPlateBackground)

                    usageExampleGroupedRows(
                        usageId: usageId,
                        chromeFooterRows: removeTailRowCount > 0
                    )
                }
            }

            Section {
                addUsageKindFooter
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                tagSelectionSection
            }
        }
    }

    // MARK: - 用法：一枚の語義カード（定義〜例文中身）／下に品詞削除

    /// 詳細画面 `UsageCardView` と横方向を揃えたカード内余白。
    private static let usageCardContentInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)

    private enum UsageExamplesSectionChrome {
        static let definitionRowInsets = usageCardContentInsets

        static var definitionPlateBackground: some View {
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(topLeading: 12, bottomLeading: 0, bottomTrailing: 0, topTrailing: 12),
                style: .continuous
            )
            .fill(Color(.systemBackground))
        }

        static let removeTailRowInsets = EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16)

        static var removeFooterPlateBackground: some View {
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 12, bottomTrailing: 12, topTrailing: 0),
                style: .continuous
            )
            .fill(Color(.systemBackground))
        }
    }

    /// 定義より下〜「例文を追加」まで：外周は単語詳細カードと同じ白地の続き。この中で例文のみ色付きスライスにする。
    private enum UsageAddCardInteriorBodySlice {
        /// 「例文」見出し行・各行のあいだ・削除フッター直前行は角丸なしで定義へつなぐ。
        case plainBodyStripe
        /// 品詞削除が無く、この行が用法カード末尾のときだけ下外周を丸める。
        case outerClosingBottomRounding
    }

    private func usageAddExampleBlockRowInsets(
        isFirstInnerRow: Bool,
        exampleExtraTailPadding: CGFloat,
        usesAdditionalInnerTopInset: Bool
    ) -> EdgeInsets {
        let baseLeading = Self.usageCardContentInsets.leading
        let baseTrailing = Self.usageCardContentInsets.trailing
        let innerTopBump: CGFloat = usesAdditionalInnerTopInset ? 10 : 0
        if isFirstInnerRow {
            /// 定義との境目では余白のみ（角丸は上位の白い定義行側のみ）。
            return EdgeInsets(
                top: 10 + innerTopBump,
                leading: baseLeading,
                bottom: 8 + exampleExtraTailPadding,
                trailing: baseTrailing
            )
        }
        return EdgeInsets(
            top: 8 + innerTopBump,
            leading: baseLeading,
            bottom: 8 + exampleExtraTailPadding,
            trailing: baseTrailing
        )
    }

    @ViewBuilder
    private func usageAddCardInteriorBodyBackground(slice: UsageAddCardInteriorBodySlice) -> some View {
        switch slice {
        case .plainBodyStripe:
            Rectangle()
                .fill(Color(.systemBackground))
        case .outerClosingBottomRounding:
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 12, bottomTrailing: 12, topTrailing: 0),
                style: .continuous
            )
            .fill(Color(.systemBackground))
        }
    }

    /// 一覧 `List` 内・用法ごとの定義ヘッダ行。
    private func usageDefinitionListRow(usageId: UUID) -> some View {
        let usage = usageBinding(for: usageId)
        return Group {
            if model.isLemmaDefinitionLocked {
                lemmaLinkedDefinitionBody(usage: usage, vocabularyHeadword: model.headword)
            } else {
                customDefinitionBlock(usage: usage, vocabularyHeadword: model.headword)
            }
        }
    }

    /// `translationTask` のセッションを保ちつつ、手入力・AI 生成で例文が変わったあとバッチ翻訳する。
    private func runFormExampleTranslationLoop(using session: TranslationSession) async {
        var lastDigest = ""
        while !Task.isCancelled {
            let digest = await MainActor.run {
                Self.formExamplesTranslationDigest(usages: model.usages, language: nativeLanguage)
            }
            if digest != lastDigest {
                lastDigest = digest
                await translateFormExamples(using: session)
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }

    private func translateFormExamples(using session: TranslationSession) async {
        let pairs: [(UUID, String)] = await MainActor.run {
            model.usages
                .flatMap(\.examples)
                .map { ($0.id, $0.sentence) }
                .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        let currentIds = Set(pairs.map(\.0))
        await MainActor.run {
            exampleTranslations = exampleTranslations.filter { currentIds.contains($0.key) }
            lastTranslatedSentenceByExampleId = lastTranslatedSentenceByExampleId.filter { currentIds.contains($0.key) }
        }

        guard !pairs.isEmpty else {
            await MainActor.run {
                exampleTranslations = [:]
                lastTranslatedSentenceByExampleId = [:]
            }
            return
        }

        let toTranslate = pairs.filter { lastTranslatedSentenceByExampleId[$0.0] != $0.1 }
        guard !toTranslate.isEmpty else { return }

        await MainActor.run {
            for (id, _) in toTranslate {
                exampleTranslations.removeValue(forKey: id)
            }
        }

        let sentSnapshot = Dictionary(uniqueKeysWithValues: toTranslate.map { ($0.0, $0.1) })

        let requests = toTranslate.map {
            TranslationSession.Request(
                sourceText: $0.1,
                clientIdentifier: $0.0.uuidString
            )
        }

        do {
            let responses = try await session.translations(from: requests)
            await MainActor.run {
                for response in responses {
                    guard let idString = response.clientIdentifier,
                          let uuid = UUID(uuidString: idString),
                          let expectedSource = sentSnapshot[uuid] else { continue }
                    let currentSource = model.usages
                        .flatMap(\.examples)
                        .first(where: { $0.id == uuid })?
                        .sentence ?? ""
                    guard currentSource == expectedSource else { continue }
                    exampleTranslations[uuid] = response.targetText
                    lastTranslatedSentenceByExampleId[uuid] = expectedSource
                }
            }
        } catch {
            // 失敗時は既存の訳を残す（オフラインなど）
        }
    }

    // MARK: - Bindings

    private func usageBinding(for id: UUID) -> Binding<UsageFormData> {
        Binding(
            get: {
                model.usages.first(where: { $0.id == id }) ?? UsageFormData(kind: .noun)
            },
            set: { newValue in
                if let index = model.usages.firstIndex(where: { $0.id == id }) {
                    model.usages[index] = newValue
                }
            }
        )
    }

    private func exampleBinding(usageId: UUID, exampleId: UUID) -> Binding<ExampleFormData> {
        Binding(
            get: {
                guard let uIndex = model.usages.firstIndex(where: { $0.id == usageId }) else {
                    return ExampleFormData()
                }
                return model.usages[uIndex].examples.first(where: { $0.id == exampleId }) ?? ExampleFormData()
            },
            set: { newValue in
                guard let uIndex = model.usages.firstIndex(where: { $0.id == usageId }),
                      let eIndex = model.usages[uIndex].examples.firstIndex(where: { $0.id == exampleId }) else { return }
                model.usages[uIndex].examples[eIndex] = newValue
            }
        )
    }

    // MARK: - Headword

    private var headwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("見出し語")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if model.isLemmaDefinitionLocked {
                Text(model.headword)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            } else {
                TextField("英単語を入力", text: $model.headword)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
            }

            if model.showDetailedEditor, model.allowsFullWordAIDraft {
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await model.generateDraft(nativeLanguage: nativeLanguage)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if model.isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(model.isGenerating ? "生成中..." : "AI生成")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.teal, lineWidth: 1)
                        )
                    }
                    .disabled(
                        model.headword.trimmingCharacters(in: .whitespaces).isEmpty
                            || model.isGenerating
                            || !model.generatingExampleIds.isEmpty
                    )
                }
            }
        }
    }

    /// 辞典候補が 0 件のときはこのボタンのみ（説明文などは出さない）。
    private var manualDictionaryEntryButton: some View {
        Button {
            model.activateManualDictionaryEntry()
        } label: {
            Text("辞典に載っていないので手入力で登録")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private var addUsageKindFooter: some View {
        Menu {
            ForEach(model.availableKinds, id: \.self) { kind in
                Button(kind.englishLabel) {
                    model.addUsage(kind: kind)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("品詞を追加")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(model.availableKinds.isEmpty || model.isLemmaDefinitionLocked)
    }

    // MARK: - Usage & examples（親 `List` の行単位）

    private func lemmaLinkedDefinitionBody(usage: Binding<UsageFormData>, vocabularyHeadword: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VocabularyPartOfSpeechCapsuleChip(kind: usage.kind.wrappedValue)

                if !usage.ipa.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(usage.ipa.wrappedValue)
                        .font(.subheadline)
                        .foregroundStyle(usage.kind.wrappedValue.badgeColor)
                }
            }

            let parentTrim = vocabularyHeadword.trimmingCharacters(in: .whitespacesAndNewlines)
            let studyTrim = usage.studyHeadword.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let studyDisplay = studyTrim.isEmpty ? parentTrim : studyTrim
            if !studyDisplay.isEmpty {
                Text(studyDisplay)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            let auxText = usage.definitionAux.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetText = usage.definitionTarget.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)

            if !auxText.isEmpty {
                Text(auxText)
                    .font(.body)
            }

            if !targetText.isEmpty {
                Text(targetText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if auxText.isEmpty && targetText.isEmpty {
                Text("辞典パックに定義が無いか、インストール済みデータが旧バージョンの可能性があります")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func customDefinitionBlock(usage: Binding<UsageFormData>, vocabularyHeadword: String) -> some View {
        let parentTrim = vocabularyHeadword.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                VocabularyPartOfSpeechCapsuleChip(kind: usage.kind.wrappedValue)

                let ipaTrim = usage.ipa.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !ipaTrim.isEmpty {
                    Text(ipaTrim)
                        .font(.subheadline)
                        .foregroundStyle(usage.kind.wrappedValue.badgeColor)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("発音記号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Self.ipaDisplayText(usage.ipa.wrappedValue))
                    .font(.body)
                    .foregroundStyle(usage.ipa.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("定義（\(nativeLanguage.displayName)）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField(nativeLanguage.definitionPlaceholder, text: usage.definitionAux)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("定義（ターゲット言語）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("英語の定義を入力", text: usage.definitionTarget)
                    .textFieldStyle(.roundedBorder)
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("例：allocated と見出しが違うとき", text: usage.studyHeadword)
                        .textFieldStyle(.roundedBorder)
                    Text(parentTrim.isEmpty ? "リスト見出しと同じなら不要です。" : "空にするとリスト見出し「\(parentTrim)」を使います。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            } label: {
                Text("この用法の単語（任意）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func ipaDisplayText(_ ipa: String) -> String {
        let t = ipa.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "保存時に辞書／生成で補完します" }
        return t
    }

    @ViewBuilder
    private func usageExampleGroupedRows(
        usageId: UUID,
        chromeFooterRows: Bool
    ) -> some View {
        let examples = model.usages.first(where: { $0.id == usageId })?.examples ?? []

        ForEach(Array(examples.enumerated()), id: \.element.id) { offset, example in
            let isLastExample = offset == examples.count - 1
            exampleEditingRowNoSwipe(usageId: usageId, exampleId: example.id, number: offset + 1)
                .padding(10)
                .background(Color.teal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .listRowInsets(
                    usageAddExampleBlockRowInsets(
                        isFirstInnerRow: false,
                        exampleExtraTailPadding: isLastExample ? 6 : 0,
                        usesAdditionalInnerTopInset: false
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(usageAddCardInteriorBodyBackground(slice: .plainBodyStripe))
                .accessibilityHint("左へスワイプしてこの例文を削除できます")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            model.removeExample(from: usageId, exampleId: example.id)
                        }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
        }

        let addOuterSlice: UsageAddCardInteriorBodySlice = chromeFooterRows ? .plainBodyStripe : .outerClosingBottomRounding
        Button {
            model.addExample(to: usageId)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("例文を追加")
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowInsets(
            usageAddExampleBlockRowInsets(isFirstInnerRow: false, exampleExtraTailPadding: 0, usesAdditionalInnerTopInset: examples.isEmpty)
        )
        .listRowSeparator(.hidden)
        .listRowBackground(usageAddCardInteriorBodyBackground(slice: addOuterSlice))

        if chromeFooterRows {
            removeUsageButton(usageId: usageId)
                .buttonStyle(.plain)
                .listRowInsets(UsageExamplesSectionChrome.removeTailRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(UsageExamplesSectionChrome.removeFooterPlateBackground)
        }
    }

    private func exampleEditingRowNoSwipe(usageId: UUID, exampleId: UUID, number: Int) -> some View {
        let example = exampleBinding(usageId: usageId, exampleId: exampleId)
        let isGeneratingThis = model.generatingExampleIds.contains(exampleId)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("例文 \(number)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer(minLength: 8)

                Button {
                    Task { await model.generateExampleSentence(usageId: usageId, exampleId: exampleId) }
                } label: {
                    HStack(spacing: 4) {
                        if isGeneratingThis {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isGeneratingThis ? "生成中…" : "AI生成")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.teal.opacity(0.6), lineWidth: 1)
                    )
                }
                .disabled(
                    model.headword.trimmingCharacters(in: .whitespaces).isEmpty
                        || model.isGenerating
                        || model.generatingExampleIds.contains(exampleId)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("英文入力欄")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                TextEditor(text: example.sentence)
                    .font(.body)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .accessibilityLabel("例文 \(number) の英文入力欄")
            }

            exampleSentenceTranslationAttachment(exampleId: exampleId)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func exampleSentenceTranslationAttachment(exampleId: UUID) -> some View {
        let trimmed = (model.usages.flatMap(\.examples).first { $0.id == exampleId }?.sentence ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if shouldTranslateExampleSentences, !trimmed.isEmpty {
            if let line = exampleTranslations[exampleId]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !line.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nativeLanguage.translationLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func removeUsageButton(usageId: UUID) -> some View {
        Button(role: .destructive) {
            model.removeUsage(usageId)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                Text("この品詞を削除")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Tag Selection

    private var tagSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タグ")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if tags.isEmpty {
                Text("タグがありません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.remoteId) { tag in
                        let isSelected = model.selectedTagIds.contains(tag.remoteId)
                        Button {
                            model.toggleTag(tag.remoteId)
                        } label: {
                            Text(tag.name)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundStyle(isSelected ? .white : .blue)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.12))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        VStack {
            Divider()
            Button {
                Task {
                    do {
                        try await model.saveForm()
                        dismiss()
                    } catch {
                        // 保存エラーは将来的にモデルへ伝播可能
                    }
                }
            } label: {
                Text("保存")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((model.canSave && model.showDetailedEditor) ? Color.blue : Color.gray)
                    )
            }
            .disabled(!model.canSave || !model.showDetailedEditor)
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }
}

private extension EdgeInsets {
    func adding(additionalTop: CGFloat = 0, additionalBottom: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(
            top: top + additionalTop,
            leading: leading,
            bottom: bottom + additionalBottom,
            trailing: trailing
        )
    }
}

#if targetEnvironment(simulator)
#Preview {
    NavigationStack {
        VocabularyAddScreen()
    }
    .modelContainer(previewContainer)
}
#endif
