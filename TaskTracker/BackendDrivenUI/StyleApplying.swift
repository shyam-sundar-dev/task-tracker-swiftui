import SwiftUI

extension View {
    @ViewBuilder
    func applyStyle(_ style: StyleProps?, resolver: TaskDataResolver) -> some View {
        if let s = style {
            self.modifier(StyleModifier(style: s, resolver: resolver))
        } else {
            self
        }
    }
}

struct StyleModifier: ViewModifier {
    let style: StyleProps
    let resolver: TaskDataResolver

    func body(content: Content) -> some View {
        content
            .applyFont(style.font)
            .applyForeground(style.foregroundStyle, resolver: resolver)
            .applyFill(style.fill, resolver: resolver)
            .applyOpacity(style.opacity)
            .applyPadding(style.padding)
            .applyFrame(style.frame, resolver: resolver)
            .applyShadow(style.shadow, resolver: resolver)
            .applyClip(style.clipShape, cornerRadius: style.cornerRadius)
    }
}

extension View {
    @ViewBuilder
    func applyFont(_ font: FontSpec?) -> some View {
        if let f = font {
            self.font(resolveFont(f))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyForeground(_ value: JSONValue?, resolver: TaskDataResolver) -> some View {
        if let v = value {
            let resolved = resolver.resolveJSONValue(v)
            self.foregroundStyle(resolver.resolveShapeStyle(resolved))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyFill(_ value: JSONValue?, resolver: TaskDataResolver) -> some View {
        // Fill is handled per-shape type in the renderer; this is a no-op on generic View
        self
    }

    @ViewBuilder
    func applyOpacity(_ opacity: Double?) -> some View {
        if let op = opacity {
            self.opacity(op)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyPadding(_ value: JSONValue?) -> some View {
        if let v = value {
            switch v {
            case .number(let n):
                self.padding(n)
            case .object(let obj):
                if let all = obj["all"]?.doubleValue {
                    self.padding(all)
                } else {
                    self.padding(EdgeInsets(
                        top:      obj["top"]?.doubleValue      ?? 0,
                        leading:  obj["leading"]?.doubleValue  ?? 0,
                        bottom:   obj["bottom"]?.doubleValue   ?? 0,
                        trailing: obj["trailing"]?.doubleValue ?? 0
                    ))
                }
            default:
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyFrame(_ spec: FrameSpec?, resolver: TaskDataResolver) -> some View {
        if let f = spec {
            let w     = resolveFrameDimension(f.width)
            let h     = resolveFrameDimension(f.height)
            let maxW  = resolveFrameDimension(f.maxWidth)
            let maxH  = resolveFrameDimension(f.maxHeight)
            let align = resolveAlignment(f.alignment)
            if w != nil || h != nil {
                self.frame(width: w, height: h, alignment: align ?? .center)
            } else if maxW != nil || maxH != nil {
                self.frame(maxWidth: maxW, maxHeight: maxH, alignment: align ?? .center)
            } else {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyShadow(_ spec: ShadowSpec?, resolver: TaskDataResolver) -> some View {
        if let s = spec {
            self.shadow(color: resolver.resolveColor(s.color), radius: s.radius, x: s.x, y: s.y)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyClip(_ shape: String?, cornerRadius: Double?) -> some View {
        switch shape {
        case "capsule":
            self.clipShape(Capsule())
        case "roundedRectangle":
            self.clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? 12))
        case "circle":
            self.clipShape(Circle())
        default:
            self
        }
    }

    // Text-specific modifiers — applies font, foreground, lineLimit, fixedSize, padding, frame
    // Strikethrough requires a Text view and is handled in UIComponentView.renderText directly.
    @ViewBuilder
    func applyTextStyle(_ style: StyleProps?, resolver: TaskDataResolver, text: String) -> some View {
        if let s = style {
            self
                .applyFont(s.font)
                .applyForeground(s.foregroundStyle, resolver: resolver)
                .applyTextLineLimit(s.lineLimit)
                .applyFixedSize(s.fixedSize)
                .applyPadding(s.padding)
                .applyFrame(s.frame, resolver: resolver)
        } else {
            self
        }
    }

    @ViewBuilder
    private func applyTextLineLimit(_ limit: Int?) -> some View {
        if let l = limit {
            self.lineLimit(l)
        } else {
            self
        }
    }

    @ViewBuilder
    private func applyFixedSize(_ spec: FixedSizeSpec?) -> some View {
        if let f = spec {
            self.fixedSize(horizontal: f.horizontal, vertical: f.vertical)
        } else {
            self
        }
    }
}

// MARK: - Helpers

private func resolveFont(_ f: FontSpec) -> Font {
    if let size = f.size {
        let base = Font.system(size: size)
        if let w = f.weight { return base.weight(resolveWeight(w)) }
        return base
    }
    if let named = f.named {
        let base: Font
        switch named {
        case "largeTitle":  base = .largeTitle
        case "title":       base = .title
        case "title2":      base = .title2
        case "title3":      base = .title3
        case "headline":    base = .headline
        case "subheadline": base = .subheadline
        case "body":        base = .body
        case "callout":     base = .callout
        case "footnote":    base = .footnote
        case "caption":     base = .caption
        case "caption2":    base = .caption2
        default:            base = .body
        }
        if let w = f.weight { return base.weight(resolveWeight(w)) }
        return base
    }
    return .body
}

private func resolveWeight(_ name: String) -> Font.Weight {
    switch name {
    case "ultraLight": return .ultraLight
    case "thin":       return .thin
    case "light":      return .light
    case "regular":    return .regular
    case "medium":     return .medium
    case "semibold":   return .semibold
    case "bold":       return .bold
    case "heavy":      return .heavy
    case "black":      return .black
    default:           return .regular
    }
}

private func resolveFrameDimension(_ value: JSONValue?) -> CGFloat? {
    guard let v = value else { return nil }
    if let s = v.stringValue, s == "infinity" { return .infinity }
    if let n = v.doubleValue { return n }
    return nil
}

private func resolveAlignment(_ name: String?) -> Alignment? {
    switch name {
    case "topLeading":    return .topLeading
    case "top":           return .top
    case "topTrailing":   return .topTrailing
    case "leading":       return .leading
    case "center":        return .center
    case "trailing":      return .trailing
    case "bottomLeading": return .bottomLeading
    case "bottom":        return .bottom
    case "bottomTrailing": return .bottomTrailing
    default:              return nil
    }
}
