import SwiftUI

// Applies a resolved FeedStyle to any node. Typography modifiers are environment
// based, so they work on containers too (children inherit font / colour).
struct FeedStyleModifier: ViewModifier {
    let style: FeedStyle?

    func body(content: Content) -> some View {
        if let s = style {
            content
                // Only set what the style declares so children keep inherited values
                .ifLet(FeedParse.font(s)) { $0.font($1) }
                .ifLet(FeedParse.color(s.foreground)) { $0.foregroundStyle($1).tint($1) }
                .ifLet(s.lineLimit) { $0.lineLimit($1) }
                .ifLet(s.textAlignment) { $0.multilineTextAlignment(FeedParse.textAlignment($1)) }
                .ifLet(s.strikethrough) { $0.strikethrough($1) }
                .ifLet(s.uppercase) { $0.textCase($1 ? .uppercase : nil) }
                .padding(.horizontal, s.paddingH ?? s.padding ?? 0)
                .padding(.vertical, s.paddingV ?? s.padding ?? 0)
                .frame(width: s.width.map { CGFloat($0) }, height: s.height.map { CGFloat($0) },
                       alignment: FeedParse.alignment(s.frameAlignment))
                .frame(maxWidth: s.fillWidth == true ? .infinity : nil,
                       alignment: FeedParse.alignment(s.frameAlignment))
                .background { background(s) }
                .overlay {
                    if let border = FeedParse.color(s.borderColor) {
                        RoundedRectangle(cornerRadius: s.cornerRadius ?? 0)
                            .strokeBorder(border, lineWidth: s.borderWidth ?? 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: s.cornerRadius ?? 0))
                .shadow(color: FeedParse.color(s.shadowColor) ?? .black.opacity(0.12),
                        radius: s.shadowRadius ?? 0, y: (s.shadowRadius ?? 0) / 2)
                .opacity(s.opacity ?? 1)
        } else {
            content
        }
    }

    @ViewBuilder
    private func background(_ s: FeedStyle) -> some View {
        if let stops = s.gradient?.compactMap(FeedParse.color), stops.count > 1 {
            LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if let bg = FeedParse.color(s.background) {
            bg
        }
    }
}

extension View {
    func feedStyle(_ style: FeedStyle?) -> some View {
        modifier(FeedStyleModifier(style: style))
    }

    @ViewBuilder
    func ifLet<T, V: View>(_ value: T?, _ transform: (Self, T) -> V) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

// MARK: - String → SwiftUI value parsing

enum FeedParse {
    private static let named: [String: Color] = [
        "primary": .primary, "secondary": .secondary, "clear": .clear,
        "white": .white, "black": .black, "gray": .gray,
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green,
        "mint": .mint, "teal": .teal, "cyan": .cyan, "blue": .blue,
        "indigo": .indigo, "purple": .purple, "pink": .pink, "brown": .brown,
    ]

    // Accepts a named colour, "#RRGGBB" or "#RRGGBBAA"
    static func color(_ raw: String?) -> Color? {
        guard let raw else { return nil }
        if let c = named[raw] { return c }
        guard raw.hasPrefix("#") else { return nil }
        let hex = String(raw.dropFirst())
        guard hex.count == 6 || hex.count == 8, let v = UInt64(hex, radix: 16) else { return nil }
        let rgba = hex.count == 6 ? (v << 8) | 0xFF : v
        return Color(
            red:     Double((rgba >> 24) & 0xFF) / 255,
            green:   Double((rgba >> 16) & 0xFF) / 255,
            blue:    Double((rgba >> 8) & 0xFF) / 255,
            opacity: Double(rgba & 0xFF) / 255
        )
    }

    static func font(_ s: FeedStyle) -> Font? {
        guard s.font != nil || s.fontSize != nil || s.weight != nil || s.design != nil else { return nil }
        let design: Font.Design = switch s.design {
            case "rounded":    .rounded
            case "monospaced": .monospaced
            case "serif":      .serif
            default:           .default
        }
        let base: Font
        if let size = s.fontSize {
            base = .system(size: size, design: design)
        } else {
            base = .system(textStyle(s.font), design: design)
        }
        return base.weight(weight(s.weight))
    }

    private static func textStyle(_ raw: String?) -> Font.TextStyle {
        switch raw {
        case "largeTitle":  .largeTitle
        case "title":       .title
        case "title2":      .title2
        case "title3":      .title3
        case "headline":    .headline
        case "subheadline": .subheadline
        case "callout":     .callout
        case "footnote":    .footnote
        case "caption":     .caption
        case "caption2":    .caption2
        default:            .body
        }
    }

    private static func weight(_ raw: String?) -> Font.Weight {
        switch raw {
        case "ultraLight": .ultraLight
        case "thin":       .thin
        case "light":      .light
        case "medium":     .medium
        case "semibold":   .semibold
        case "bold":       .bold
        case "heavy":      .heavy
        case "black":      .black
        default:           .regular
        }
    }

    static func textAlignment(_ raw: String?) -> TextAlignment {
        switch raw {
        case "center":   .center
        case "trailing": .trailing
        default:         .leading
        }
    }

    static func horizontal(_ raw: String?) -> HorizontalAlignment {
        switch raw {
        case "leading":  .leading
        case "trailing": .trailing
        default:         .center
        }
    }

    static func vertical(_ raw: String?) -> VerticalAlignment {
        switch raw {
        case "top":    .top
        case "bottom": .bottom
        default:       .center
        }
    }

    static func alignment(_ raw: String?) -> Alignment {
        switch raw {
        case "leading":        .leading
        case "trailing":       .trailing
        case "top":            .top
        case "bottom":         .bottom
        case "topLeading":     .topLeading
        case "topTrailing":    .topTrailing
        case "bottomLeading":  .bottomLeading
        case "bottomTrailing": .bottomTrailing
        default:               .center
        }
    }
}
