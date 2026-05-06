import SwiftUI
import SwiftData

@main
struct PeraTalkApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedSession.self,
            CachedUtterance.self,
            CachedSessionFeedback.self,
            CachedLemma.self,
            CachedLemmaSurface.self,
            CachedDictionaryPackMeta.self,
            CachedVocabulary.self,
            CachedVocabularyUsage.self,
            CachedVocabularyExample.self,
            CachedTag.self,
            CachedVocabularyTagLink.self,
            CachedPersona.self,
            CachedTheme.self,
            CachedSessionMemorySummary.self,
            CachedProfile.self,
            CachedSubscription.self,
            SyncMeta.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SeedDataService.loadIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
