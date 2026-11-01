import Foundation

struct StyleProps: Codable {
    var font: FontSpec?
    var foregroundStyle: JSONValue?
    var fill: JSONValue?
    var background: JSONValue?
    var padding: JSONValue?
    var frame: FrameSpec?
    var cornerRadius: Double?
    var clipShape: String?
    var shadow: ShadowSpec?
    var opacity: Double?
    var lineLimit: Int?
    var strikethrough: JSONValue?
    var fixedSize: FixedSizeSpec?
}

struct FontSpec: Codable {
    var named: String?
    var size: Double?
    var weight: String?
}

struct FrameSpec: Codable {
    var width: JSONValue?
    var height: JSONValue?
    var maxWidth: JSONValue?
    var maxHeight: JSONValue?
    var alignment: String?
}

struct ShadowSpec: Codable {
    var color: String
    var radius: Double
    var x: Double
    var y: Double
}

struct FixedSizeSpec: Codable {
    var horizontal: Bool
    var vertical: Bool
}

struct PaddingSpec: Codable {
    var top: Double?
    var leading: Double?
    var bottom: Double?
    var trailing: Double?
    var all: Double?
}

// MARK: - Style merging (styleClass base + inline override — same model as CSS class < inline)

extension StyleProps {
    func merging(_ override: StyleProps) -> StyleProps {
        StyleProps(
            font:            override.font            ?? self.font,
            foregroundStyle: override.foregroundStyle ?? self.foregroundStyle,
            fill:            override.fill            ?? self.fill,
            background:      override.background      ?? self.background,
            padding:         override.padding         ?? self.padding,
            frame:           override.frame           ?? self.frame,
            cornerRadius:    override.cornerRadius    ?? self.cornerRadius,
            clipShape:       override.clipShape       ?? self.clipShape,
            shadow:          override.shadow          ?? self.shadow,
            opacity:         override.opacity         ?? self.opacity,
            lineLimit:       override.lineLimit       ?? self.lineLimit,
            strikethrough:   override.strikethrough   ?? self.strikethrough,
            fixedSize:       override.fixedSize       ?? self.fixedSize
        )
    }
}
