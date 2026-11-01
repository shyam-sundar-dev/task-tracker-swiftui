import Foundation

// Simulates the server layer: loads all layout definitions from the app bundle
// and wraps them in LayoutResponse payloads.
//
// In production, replace the body with URLSession fetches to your layout API.
// Layout and data (Task[]) are fetched independently — separate lifecycles.
enum LayoutService {
    private static let catalog: [(id: String, file: String, version: Int)] = [
        ("task_card",    "task_card_layout",    1),
        ("task_compact", "task_compact_layout", 1),
    ]

    static func fetchAll() async -> [LayoutResponse] {
        catalog.compactMap { item in
            guard let def = try? ComponentLoader.load(named: item.file) else { return nil }
            // Stylesheet comes from the bundle definition; top-level wins in LayoutCache
            return LayoutResponse(
                layoutID:   item.id,
                version:    item.version,
                layout:     def,
                stylesheet: def.stylesheet ?? [:]
            )
        }
    }
}
