import SwiftUI

@main struct MyApp: App {
    // Parsed JSON tree (used by interpreted BDUI mode)
    private let cardDefinition: ComponentDefinition? = {
        try? ComponentLoader.load(named: "task_card_layout")
    }()

    // Cache of compiled layouts — cells read from here via @Environment
    @State private var layoutCache = LayoutCache()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.cardComponentDefinition, cardDefinition)
                .environment(layoutCache)
        }
    }
}
