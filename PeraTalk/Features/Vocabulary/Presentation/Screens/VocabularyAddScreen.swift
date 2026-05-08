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

    private var nativeLanguage: AuxiliaryLanguage {
        guard let raw = profiles.first?.auxiliaryLanguage else { return .systemDefault }
        return AuxiliaryLanguage(rawValue: raw) ?? .japanese
    }

    init(vocabularyId: UUID? = nil) {
        self.editVocabularyId = vocabularyId
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
                model = VocabularyAddScreenModel.live(modelContext: modelContext)
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
        let stack = VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headwordSection

                    if model.showLemmaSearchFlow,
                       !model.useManualDictionaryBypass,
                       model.linkedLemmaStableId == nil {
                        lemmaCandidateSearchSection
                    }

                    if model.showDetailedEditor {
                        ForEach(model.usages) { usage in
                            usageEditingCard(usageId: usage.id)
                                .id(usage.id)
                        }

                        addUsageKindFooter

                        tagSelectionSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .onChange(of: model.headword) { _, _ in
                model.scheduleLemmaCandidateRefresh()
            }

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
                            let tagItems = tags.map { TagPickerItem(remoteId: $0.remoteId, name: $0.name) }
                            await model.generateDraft(tagItems: tagItems, nativeLanguage: nativeLanguage)
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

    @ViewBuilder
    private var lemmaCandidateSearchSection: some View {
        let query = model.headword.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            if model.isLemmaLookupPending {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("辞典を検索中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                                            Text(kind.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
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
    }

    // MARK: - Usage cards

    private var addUsageKindFooter: some View {
        Menu {
            ForEach(model.availableKinds, id: \.self) { kind in
                Button(kind.displayName) {
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

    private func usageEditingCard(usageId: UUID) -> some View {
        let usage = usageBinding(for: usageId)
        return VStack(alignment: .leading, spacing: 16) {
            if model.isLemmaDefinitionLocked {
                lemmaLinkedDefinitionBody(usage: usage)
            } else {
                customDefinitionBlock(usage: usage)
            }

            Divider()
                .opacity(0.45)

            usageExamplesContent(usageId: usageId)

            if !model.isLemmaDefinitionLocked {
                removeUsageButton(usageId: usageId)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func lemmaLinkedDefinitionBody(usage: Binding<UsageFormData>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(usage.kind.wrappedValue.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Color.teal))

                if !usage.ipa.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(usage.ipa.wrappedValue)
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }
            }

            let auxText = usage.definitionAux.wrappedValue.trimmingCharacters(in: .whitespaces)
            let targetText = usage.definitionTarget.wrappedValue.trimmingCharacters(in: .whitespaces)

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

    private func customDefinitionBlock(usage: Binding<UsageFormData>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(usage.kind.wrappedValue.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Color.teal))

                let ipaTrim = usage.ipa.wrappedValue.trimmingCharacters(in: .whitespaces)
                if !ipaTrim.isEmpty {
                    Text(ipaTrim)
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("発音記号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Self.ipaDisplayText(usage.ipa.wrappedValue))
                    .font(.body)
                    .foregroundStyle(usage.ipa.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty ? .tertiary : .primary)
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
        }
    }

    private static func ipaDisplayText(_ ipa: String) -> String {
        let t = ipa.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "保存時に辞書／生成で補完します" }
        return t
    }

    private func usageExamplesContent(usageId: UUID) -> some View {
        let examples = model.usages.first(where: { $0.id == usageId })?.examples ?? []
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(examples.enumerated()), id: \.element.id) { number, example in
                exampleEditingRow(
                    usageId: usageId,
                    exampleId: example.id,
                    number: number + 1,
                    canDelete: examples.count > 1
                )
            }

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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }

    private func exampleEditingRow(usageId: UUID, exampleId: UUID, number: Int, canDelete: Bool) -> some View {
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

            Text("英文")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: example.sentence)
                .frame(minHeight: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            exampleSentenceTranslationAttachment(exampleId: exampleId)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if canDelete {
                Button("削除", role: .destructive) {
                    model.removeExample(from: usageId, exampleId: exampleId)
                }
            }
        }
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

#Preview {
    NavigationStack {
        VocabularyAddScreen()
    }
    .modelContainer(previewContainer)
}
