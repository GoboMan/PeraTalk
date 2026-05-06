import SwiftUI

struct LogCalendarScreen: View {
    @State private var model = LogCalendarScreenModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("SCR-LOG-CALENDAR")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("学習ログ・カレンダー画面")
                    .font(.title)

                VStack(alignment: .leading, spacing: 12) {
                    Text("・月単位カレンダー表示")
                    Text("・学習日のハイライト")
                    Text("・前後月への切り替え")
                    Text("・学習ありの日をタップ → 日付詳細へ")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding()
            .navigationTitle("学習ログ")
        }
    }
}
