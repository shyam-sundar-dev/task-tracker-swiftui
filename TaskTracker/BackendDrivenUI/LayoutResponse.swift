import Foundation

// The server contract: layout, stylesheet, and metadata arrive together.
// Layout and data travel as separate API calls — independent lifecycles.
struct LayoutResponse: Codable {
    let layoutID:   String             // stable identifier, e.g. "task_card"
    let version:    Int                // bump when layout or stylesheet changes
    let layout:     ComponentDefinition
    let stylesheet: StyleSheet         // global stylesheet for this response
}
