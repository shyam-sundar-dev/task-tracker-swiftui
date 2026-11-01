import SwiftUI

// A pre-baked card layout built once at startup from the UIComponent tree.
// Each call to `build(resolver)` produces the full card view inline — no child
// UIComponentView structs are created, so SwiftUI sees 1 body eval per card
// (same as a handwritten native view) instead of one per tree node.
struct CompiledLayout {
    let build: (TaskDataResolver) -> AnyView
}

// MARK: - Compiler

enum LayoutCompiler {

    // nonisolated so LayoutCache can call this from a detached Task without actor hops
    nonisolated static func compile(_ root: UIComponent, stylesheet: StyleSheet = [:]) -> CompiledLayout {
        let builder = node(root, stylesheet: stylesheet)
        return CompiledLayout(build: builder)
    }

    // MARK: Recursive node compiler

    private static func node(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        switch c.type {
        case "ZStack":           return zStack(c, stylesheet: stylesheet)
        case "HStack":           return hStack(c, stylesheet: stylesheet)
        case "VStack":           return vStack(c, stylesheet: stylesheet)
        case "Text":             return text(c, stylesheet: stylesheet)
        case "Image":            return image(c, stylesheet: stylesheet)
        case "Spacer":           return { _ in AnyView(Spacer()) }
        case "Divider":          return { _ in AnyView(Divider()) }
        case "RoundedRectangle": return roundedRect(c, stylesheet: stylesheet)
        case "Capsule":          return capsule(c, stylesheet: stylesheet)
        case "Circle":           return circle(c, stylesheet: stylesheet)
        case "ForEach":          return forEach(c, stylesheet: stylesheet)
        case "NativeComponent":  return native(c)
        default:                 return { _ in AnyView(EmptyView()) }
        }
    }

    // Resolves styleClass base + inline override into final StyleProps.
    // Rule: styleClass is the base; inline style wins on any non-nil field.
    private static func resolvedStyle(_ c: UIComponent, stylesheet: StyleSheet) -> StyleProps? {
        switch (c.styleClass, c.style) {
        case (nil, let inline):          return inline
        case (let cls?, nil):            return stylesheet[cls]
        case (let cls?, let inline?):    return stylesheet[cls]?.merging(inline) ?? inline
        }
    }

    // Pre-compile all children once; captured in closures, not re-parsed per render.
    private static func children(_ c: UIComponent, stylesheet: StyleSheet) -> [(TaskDataResolver) -> AnyView] {
        (c.children ?? []).map { node($0, stylesheet: stylesheet) }
    }

    // MARK: Container builders

    private static func zStack(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let alignment = hVAlignment(c.props?["alignment"]?.stringValue) ?? .center
        let builders  = children(c, stylesheet: stylesheet)
        let style     = resolvedStyle(c, stylesheet: stylesheet)
        return { resolver in
            AnyView(
                ZStack(alignment: alignment) {
                    ForEach(0..<builders.count, id: \.self) { i in
                        builders[i](resolver)
                    }
                }
                .modifier(CompiledStyleModifier(style: style, resolver: resolver))
            )
        }
    }

    private static func hStack(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let alignment = vAlignment(c.props?["alignment"]?.stringValue) ?? .center
        let spacing   = c.props?["spacing"]?.doubleValue.map { CGFloat($0) }
        let builders  = children(c, stylesheet: stylesheet)
        let style     = resolvedStyle(c, stylesheet: stylesheet)
        return { resolver in
            AnyView(
                HStack(alignment: alignment, spacing: spacing) {
                    ForEach(0..<builders.count, id: \.self) { i in
                        builders[i](resolver)
                    }
                }
                .modifier(CompiledStyleModifier(style: style, resolver: resolver))
            )
        }
    }

    private static func vStack(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let alignment = hAlignment(c.props?["alignment"]?.stringValue) ?? .leading
        let spacing   = c.props?["spacing"]?.doubleValue.map { CGFloat($0) }
        let builders  = children(c, stylesheet: stylesheet)
        let style     = resolvedStyle(c, stylesheet: stylesheet)
        return { resolver in
            AnyView(
                VStack(alignment: alignment, spacing: spacing) {
                    ForEach(0..<builders.count, id: \.self) { i in
                        builders[i](resolver)
                    }
                }
                .modifier(CompiledStyleModifier(style: style, resolver: resolver))
            )
        }
    }

    // MARK: Leaf builders

    private static func text(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let rawContent    = c.props?["content"]?.stringValue ?? ""
        let style         = resolvedStyle(c, stylesheet: stylesheet)
        let strikethrough = style?.strikethrough   // pre-captured from merged style
        return { resolver in
            let content = resolver.resolveString(rawContent)
            let isStruck: Bool = {
                guard let sv = strikethrough else { return false }
                switch sv {
                case .bool(let b):   return b
                case .string(let s): return resolver.resolveBool(s)
                default:             return false
                }
            }()
            if isStruck {
                return AnyView(Text(content)
                    .strikethrough(true)
                    .applyTextStyle(style, resolver: resolver, text: content))
            } else {
                return AnyView(Text(content)
                    .applyTextStyle(style, resolver: resolver, text: content))
            }
        }
    }

    private static func image(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let rawName = c.props?["systemName"]?.stringValue ?? ""
        let style   = resolvedStyle(c, stylesheet: stylesheet)
        return { resolver in
            let name = resolver.resolveString(rawName)
            return AnyView(Image(systemName: name)
                .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
        }
    }

    // MARK: Shape builders

    private static func roundedRect(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let resolved  = resolvedStyle(c, stylesheet: stylesheet)
        let cr        = c.props?["cornerRadius"]?.doubleValue ?? resolved?.cornerRadius ?? 12
        let fillValue = resolved?.fill
        let style     = withoutFill(resolved)
        return { resolver in
            if let fv = fillValue {
                return AnyView(RoundedRectangle(cornerRadius: cr)
                    .fill(resolver.resolveShapeStyle(fv))
                    .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
            } else {
                return AnyView(RoundedRectangle(cornerRadius: cr)
                    .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
            }
        }
    }

    private static func capsule(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let resolved  = resolvedStyle(c, stylesheet: stylesheet)
        let fillValue = resolved?.fill
        let style     = withoutFill(resolved)
        return { resolver in
            if let fv = fillValue {
                return AnyView(Capsule()
                    .fill(resolver.resolveShapeStyle(fv))
                    .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
            } else {
                return AnyView(Capsule()
                    .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
            }
        }
    }

    private static func circle(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        let resolved  = resolvedStyle(c, stylesheet: stylesheet)
        let fillValue = resolved?.fill
        let style     = withoutFill(resolved)
        return { resolver in
            if let fv = fillValue {
                return AnyView(Circle()
                    .fill(resolver.resolveShapeStyle(fv))
                    .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
            } else {
                return AnyView(Circle()
                    .modifier(CompiledStyleModifier(style: style, resolver: resolver)))
            }
        }
    }

    // MARK: ForEach builder

    private static func forEach(_ c: UIComponent, stylesheet: StyleSheet) -> (TaskDataResolver) -> AnyView {
        guard let spec = c.forEach else { return { _ in AnyView(EmptyView()) } }
        let itemBuilders = (c.children ?? []).map { node($0, stylesheet: stylesheet) }
        let dataBinding  = spec.dataBinding
        let itemAlias    = spec.itemAlias
        return { resolver in
            let items = resolver.resolveStrings(dataBinding)
            return AnyView(ForEach(items, id: \.self) { item in
                let childResolver = resolver.childResolver(itemAlias: itemAlias, value: item)
                ForEach(0..<itemBuilders.count, id: \.self) { i in
                    itemBuilders[i](childResolver)
                }
            })
        }
    }

    // MARK: NativeComponent builder — domain views stay in Swift

    private static func native(_ c: UIComponent) -> (TaskDataResolver) -> AnyView {
        let name  = c.props?["name"]?.stringValue ?? ""
        let props = c.props                        // pre-captured dict, not re-parsed

        switch name {
        case "CategoryPill":
            return { resolver in
                AnyView(CategoryPill(
                    category: resolver.resolveCategory(props?["category"]),
                    color:    resolver.resolveColor(props?["color"]?.stringValue ?? "$categoryColor")
                ))
            }
        case "PriorityDot":
            return { resolver in
                AnyView(PriorityDot(priority: resolver.resolvePriority(props?["priority"])))
            }
        case "CompletionBadge":
            let expr = c.props?["isCompleted"]?.stringValue ?? "$task.isCompleted"
            return { resolver in
                AnyView(NativeCompletionBadge(isCompleted: resolver.resolveBool(expr)))
            }
        case "AssigneeStack":
            return { resolver in AnyView(AssigneeStack(assignees: resolver.task.assignees)) }
        case "TagChip":
            let expr = c.props?["label"]?.stringValue ?? ""
            return { resolver in
                AnyView(TagChip(label: resolver.resolveString(expr)))
            }
        case "MetaLabel":
            let symbol  = c.props?["symbol"]?.stringValue ?? ""
            let valExpr = c.props?["value"]?.stringValue ?? ""
            return { resolver in
                AnyView(MetaLabel(symbol: symbol, value: resolver.resolveString(valExpr)))
            }
        case "ProgressBar":
            let progressExpr = c.props?["progress"]?.stringValue ?? "$task.progress"
            let colorExpr    = c.props?["color"]?.stringValue    ?? "$categoryColor"
            return { resolver in
                AnyView(NativeProgressBar(
                    progress: resolver.resolveDouble(progressExpr),
                    color:    resolver.resolveColor(colorExpr)
                ))
            }
        default:
            return { _ in AnyView(EmptyView()) }
        }
    }

    // MARK: Alignment helpers (pre-parsed at compile time)

    private static func hVAlignment(_ s: String?) -> Alignment? {
        switch s {
        case "topLeading":     return .topLeading
        case "top":            return .top
        case "topTrailing":    return .topTrailing
        case "leading":        return .leading
        case "center":         return .center
        case "trailing":       return .trailing
        case "bottomLeading":  return .bottomLeading
        case "bottom":         return .bottom
        case "bottomTrailing": return .bottomTrailing
        default:               return nil
        }
    }

    private static func hAlignment(_ s: String?) -> HorizontalAlignment? {
        switch s {
        case "leading":  return .leading
        case "center":   return .center
        case "trailing": return .trailing
        default:         return nil
        }
    }

    private static func vAlignment(_ s: String?) -> VerticalAlignment? {
        switch s {
        case "top":    return .top
        case "center": return .center
        case "bottom": return .bottom
        default:       return nil
        }
    }

    private static func withoutFill(_ style: StyleProps?) -> StyleProps? {
        guard var s = style else { return nil }
        s.fill = nil
        return s
    }
}

// MARK: - Compiled style modifier

// Identical to StyleModifier in StyleApplying.swift but used by the compiler path.
// Kept separate so the interpreter and compiled paths stay independent.
struct CompiledStyleModifier: ViewModifier {
    let style: StyleProps?
    let resolver: TaskDataResolver

    func body(content: Content) -> some View {
        if let s = style {
            content.modifier(StyleModifier(style: s, resolver: resolver))
        } else {
            content
        }
    }
}
