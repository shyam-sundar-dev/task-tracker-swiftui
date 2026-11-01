import Foundation

struct UIComponent: Codable {
    let type: String
    var props: [String: JSONValue]?
    var style: StyleProps?        // inline override — highest specificity
    var styleClass: String?       // references a named stylesheet entry
    var children: [UIComponent]?
    var forEach: ForEachSpec?
    var comment: String?

    // Stable identity for renderer ForEach — structural, not data identity
    var instanceID: String {
        "\(type)_\(props?["name"]?.stringValue ?? props?["content"]?.stringValue ?? "")"
    }
}

struct ForEachSpec: Codable {
    let dataBinding: String
    let itemAlias: String
}

struct ComponentDefinition: Codable {
    let componentVersion: Int
    let stylesheet: StyleSheet?   // optional inline stylesheet (backward-compatible)
    let root: UIComponent
}
