import SwiftUI

/// 単語詳細のナビゲーションバー右上メニュー（ペジャーでは親に 1 つだけ載せる）。
struct VocabularyDetailTrailingMenu: View {
    @Binding var path: NavigationPath
    let vocabularyRemoteId: UUID
    /// `nil` のときはメニューに「意味を伏せるモード」を出さない（単独詳細など）。
    var recallObfuscationModeEnabled: Binding<Bool>?

    var body: some View {
        Menu {
            if let recallBinding = recallObfuscationModeEnabled {
                Toggle(isOn: recallBinding) {
                    Label("意味を伏せるモード", systemImage: "rectangle.and.text.magnifyingglass")
                }
            }
            Button {
                path.append(VocabularyRoute.edit(vocabularyRemoteId))
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
