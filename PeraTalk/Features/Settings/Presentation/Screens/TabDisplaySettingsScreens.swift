import SwiftUI
import SwiftData

// MARK: - Bindings（SwiftUI とユースケースの境界）

private enum ScreenDisplaySettingsViewBindings {
    static func calendarFirstWeekday(_ model: ScreenDisplaySettingsScreenModel) -> Binding<CalendarFirstWeekdayPreference> {
        Binding(
            get: { model.preferences.learningLog.calendarFirstWeekday },
            set: { newValue in
                Task { await model.update { $0.learningLog.calendarFirstWeekday = newValue } }
            }
        )
    }

    static func showConversationGuide(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.conversation.showStartScreenGuide },
            set: { newValue in
                Task { await model.update { $0.conversation.showStartScreenGuide = newValue } }
            }
        )
    }

    static func vocabularySortOrder(_ model: ScreenDisplaySettingsScreenModel) -> Binding<VocabularyListSortOrder> {
        Binding(
            get: { model.preferences.vocabularyList.sortOrder },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.sortOrder = newValue } }
            }
        )
    }

    static func vocabularyListDensity(_ model: ScreenDisplaySettingsScreenModel) -> Binding<ListRowDensity> {
        Binding(
            get: { model.preferences.vocabularyList.listDensity },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.listDensity = newValue } }
            }
        )
    }

    static func vocabularyShowJapaneseDefinition(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.vocabularyList.showJapaneseDefinition },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.showJapaneseDefinition = newValue } }
            }
        )
    }

    static func vocabularyShowEnglishDefinition(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.vocabularyList.showEnglishDefinition },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.showEnglishDefinition = newValue } }
            }
        )
    }

    static func vocabularyShowPronunciation(_ model: ScreenDisplaySettingsScreenModel) -> Binding<Bool> {
        Binding(
            get: { model.preferences.vocabularyList.showPronunciation },
            set: { newValue in
                Task { await model.update { $0.vocabularyList.showPronunciation = newValue } }
            }
        )
    }
}

// MARK: - 学習ログ

struct LearningLogDisplaySettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: ScreenDisplaySettingsScreenModel?

    var body: some View {
        Group {
            if let model {
                Form {
                    Section {
                        Picker("週の始まり", selection: ScreenDisplaySettingsViewBindings.calendarFirstWeekday(model)) {
                            ForEach(CalendarFirstWeekdayPreference.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    } footer: {
                        Text("カレンダー実装時に、この設定が週グリッドの並びに反映されます。")
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("学習ログ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadModelIfNeeded()
        }
    }

    private func loadModelIfNeeded() async {
        if model == nil {
            model = ScreenDisplaySettingsScreenModel.live(modelContext: modelContext)
        }
        await model?.load()
    }
}

// MARK: - 会話

struct ConversationDisplaySettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model: ScreenDisplaySettingsScreenModel?

    var body: some View {
        Group {
            if let model {
                Form {
                    Section {
                        Toggle("開始画面のガイドを表示", isOn: ScreenDisplaySettingsViewBindings.showConversationGuide(model))
                    } footer: {
                        Text("会話タブの説明テキストやプレースホルダーUIの表示を切り替えられます。")
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("会話")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadModelIfNeeded()
        }
    }

    private func loadModelIfNeeded() async {
        if model == nil {
            model = ScreenDisplaySettingsScreenModel.live(modelContext: modelContext)
        }
        await model?.load()
    }
}

// MARK: - 単語帳

struct VocabularyTabDisplaySettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supabaseTableClient) private var supabaseTableClient
    @State private var model: ScreenDisplaySettingsScreenModel?
    @State private var dictionaryPackSyncBanner: String?
    @State private var isDictionaryPackSyncing = false

    var body: some View {
        Group {
            if let model {
                Form {
                    Section {
                        Picker("並び順", selection: ScreenDisplaySettingsViewBindings.vocabularySortOrder(model)) {
                            ForEach(VocabularyListSortOrder.allCases) { order in
                                Text(order.displayName).tag(order)
                            }
                        }

                        Picker("一覧の行間", selection: ScreenDisplaySettingsViewBindings.vocabularyListDensity(model)) {
                            ForEach(ListRowDensity.allCases) { density in
                                Text(density.displayName).tag(density)
                            }
                        }
                    }

                    Section {
                        Toggle("日本語訳を表示", isOn: ScreenDisplaySettingsViewBindings.vocabularyShowJapaneseDefinition(model))
                        Toggle("英訳を表示", isOn: ScreenDisplaySettingsViewBindings.vocabularyShowEnglishDefinition(model))
                        Toggle("発音を表示", isOn: ScreenDisplaySettingsViewBindings.vocabularyShowPronunciation(model))
                    } header: {
                        Text("一覧カードに表示する項目")
                    } footer: {
                        Text("見出し語は常に表示されます。品詞は一覧では表示せず、単語詳細で用法ごとに表示します。発音は用法に IPA などが登録されているときに表示されます。")
                    }

                    Section {
                        Button {
                            Task { await syncDictionaryPackFromServer() }
                        } label: {
                            Label("サーバーから辞書を同期", systemImage: "arrow.down.circle")
                        }
                        .disabled(isDictionaryPackSyncing)
                    } header: {
                        Text("辞書データ")
                    } footer: {
                        Text("サーバー上のカタログから辞書パックを取り込み、単語帳で参照する語形データを更新します。")
                    }
                }
                .alert("辞書パック", isPresented: Binding(
                    get: { dictionaryPackSyncBanner != nil },
                    set: { if !$0 { dictionaryPackSyncBanner = nil } }
                )) {
                    Button("OK") { dictionaryPackSyncBanner = nil }
                } message: {
                    Text(dictionaryPackSyncBanner ?? "")
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("単語帳")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadModelIfNeeded()
        }
    }

    private func syncDictionaryPackFromServer() async {
        dictionaryPackSyncBanner = nil
        guard !isDictionaryPackSyncing else { return }
        isDictionaryPackSyncing = true
        defer { isDictionaryPackSyncing = false }
        dictionaryPackSyncBanner = await CatalogRemoteDictionaryPackLiveSync.syncResultMessage(
            context: modelContext,
            supabaseTableClient: supabaseTableClient
        )
    }

    private func loadModelIfNeeded() async {
        if model == nil {
            model = ScreenDisplaySettingsScreenModel.live(modelContext: modelContext)
        }
        await model?.load()
    }
}

// MARK: - Previews

#if targetEnvironment(simulator)
#Preview("学習ログ") {
    NavigationStack {
        LearningLogDisplaySettingsScreen()
    }
    .modelContainer(previewContainer)
}

#Preview("会話") {
    NavigationStack {
        ConversationDisplaySettingsScreen()
    }
    .modelContainer(previewContainer)
}

#Preview("単語帳") {
    NavigationStack {
        VocabularyTabDisplaySettingsScreen()
    }
    .modelContainer(previewContainer)
}
#endif
