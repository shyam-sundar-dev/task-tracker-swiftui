import Foundation

// Feed payload split into three independent concerns:
//   1. layout — pure structure (stacks, labels, images…). Nodes only reference
//      a styleId and/or a dataId, never raw values.
//   2. styles — shared, document-level map of styleId → visual properties.
//   3. data   — per-item map of dataId → content (text, image, nested items).
//
// The same layout can therefore be reused with different data, and restyled
// without touching structure or content.
struct FeedDocument: Decodable {
    let styles: [String: FeedStyle]
    // Reusable layout templates; many items share one layout with different data
    let layouts: [String: FeedNode]
    let items: [FeedItem]
}

struct FeedItem: Decodable, Identifiable {
    let id: String
    let layoutId: String
    let data: [String: FeedData]
}

enum FeedNodeType: String, Decodable {
    case vstack, hstack, zstack
    case label, image
    case spacer, divider
    case progress
    // Collections: render `template` once per entry in data[dataId].items
    case carousel, grid
    case vlist      // nested vertical ScrollView; give it a height via style
}

final class FeedNode: Decodable {
    let type: FeedNodeType
    let styleId: String?
    let dataId: String?
    let spacing: Double?
    let alignment: String?
    let children: [FeedNode]?
    // Collection-only
    let template: FeedNode?
    let columns: Int?
    let inset: Double?
}

struct FeedData: Decodable {
    var text: String?
    var symbol: String?      // SF Symbol name
    var url: String?         // remote image
    var value: Double?       // progress 0…1
    var items: [[String: FeedData]]?
}

struct FeedStyle: Decodable {
    // Typography
    var font: String?            // largeTitle, title, headline, body, caption…
    var fontSize: Double?        // overrides `font` when set
    var weight: String?
    var design: String?          // rounded, monospaced, serif
    var lineLimit: Int?
    var textAlignment: String?   // leading, center, trailing
    var strikethrough: Bool?
    var uppercase: Bool?

    // Colour
    var foreground: String?
    var background: String?
    var gradient: [String]?      // overrides `background`
    var opacity: Double?

    // Box
    var padding: Double?
    var paddingH: Double?
    var paddingV: Double?
    var width: Double?
    var height: Double?
    var fillWidth: Bool?
    var frameAlignment: String?
    var cornerRadius: Double?
    var borderColor: String?
    var borderWidth: Double?
    var shadowRadius: Double?
    var shadowColor: String?

    // Image
    var contentMode: String?     // fit, fill
}

enum FeedLoader {
    static func load(named name: String) -> FeedDocument? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(FeedDocument.self, from: data)
        } catch {
            print("FeedLoader: failed to decode \(name): \(error)")
            return nil
        }
    }
}
