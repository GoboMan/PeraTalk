import SwiftData
import SwiftUI

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

#Preview("単語帳") {
    NavigationStack {
        VocabularyTabDisplaySettingsScreen()
    }
    .modelContainer(previewContainer)
}
