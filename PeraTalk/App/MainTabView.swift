import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Log", systemImage: "list.bullet.rectangle") {
                LogCalendarScreen()
            }

            Tab("Talk", systemImage: "bubble.left.and.bubble.right") {
                ConversationStartScreen()
            }

            Tab("Vocabulary", systemImage: "book") {
                VocabularyListScreen()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsScreen()
            }
        }
    }
}

#if targetEnvironment(simulator)
#Preview {
    MainTabView()
        .modelContainer(previewContainer)
}
#endif
