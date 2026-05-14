import SwiftData
import Supabase
import SwiftUI

@main
struct PeraTalkApp: App {
    private let supabaseLiveKit: SupabaseClientFactory.LiveKit?
    private let liveAuthService: LiveSupabaseAuthService?

    init() {
        let kit = SupabaseClientFactory.makeLiveKitIfConfigured()
        supabaseLiveKit = kit
        if let kit {
            liveAuthService = LiveSupabaseAuthService(client: kit.client)
        } else {
            liveAuthService = nil
        }
    }

    private var injectedAuthService: any AuthService {
        if let liveAuthService { liveAuthService }
        else { StubAuthService() }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedSession.self,
            CachedUtterance.self,
            CachedSessionFeedback.self,
            CachedLemma.self,
            CachedLemmaUsage.self,
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

        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }

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
                .environment(\.supabaseClient, supabaseLiveKit?.client)
                .environment(\.supabaseTableClient, supabaseLiveKit?.tableClient)
                .environment(\.supabaseEdgeFunctionsClient, supabaseLiveKit?.edgeFunctionsClient)
                .environment(\.authService, injectedAuthService)
                .onOpenURL { url in
                    supabaseLiveKit?.client.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
