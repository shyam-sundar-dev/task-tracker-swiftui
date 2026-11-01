import SwiftUI

struct UIComponentView: View {
    let component: UIComponent
    let resolver: TaskDataResolver
    var stylesheet: StyleSheet = [:]

    var body: some View {
        let _ = BodyEvalCounter.shared.nodeTick()
        return renderComponent(component)
    }

    // Resolves styleClass base + inline override — same specificity model as LayoutCompiler.
    private func effectiveStyle(_ c: UIComponent) -> StyleProps? {
        switch (c.styleClass, c.style) {
        case (nil, let inline):          return inline
        case (let cls?, nil):            return stylesheet[cls]
        case (let cls?, let inline?):    return stylesheet[cls]?.merging(inline) ?? inline
        }
    }

    @ViewBuilder
    func renderComponent(_ c: UIComponent) -> some View {
        switch c.type {
        case "ZStack":          renderZStack(c)
        case "HStack":          renderHStack(c)
        case "VStack":          renderVStack(c)
        case "Text":            renderText(c)
        case "Image":           renderImage(c)
        case "Spacer":          Spacer()
        case "Divider":         Divider()
        case "RoundedRectangle": renderRoundedRect(c)
        case "Capsule":         renderCapsule(c)
        case "Circle":          renderCircle(c)
        case "ForEach":         renderForEach(c)
        case "NativeComponent": renderNative(c)
        default:                EmptyView()
        }
    }

    // MARK: - Container renderers

    @ViewBuilder
    private func renderZStack(_ c: UIComponent) -> some View {
        let alignment = hVAlignment(c.props?["alignment"]?.stringValue) ?? .center
        ZStack(alignment: alignment) {
            childrenViews(c)
        }
        .applyStyle(effectiveStyle(c), resolver: resolver)
    }

    @ViewBuilder
    private func renderHStack(_ c: UIComponent) -> some View {
        let spacing = c.props?["spacing"]?.doubleValue
        let alignment = vAlignment(c.props?["alignment"]?.stringValue) ?? .center
        HStack(alignment: alignment, spacing: CGFloat(spacing ?? 0.0)) {
            childrenViews(c)
        }
        .applyStyle(effectiveStyle(c), resolver: resolver)
    }

    @ViewBuilder
    private func renderVStack(_ c: UIComponent) -> some View {
        let spacing = c.props?["spacing"]?.doubleValue
        let alignment = hAlignment(c.props?["alignment"]?.stringValue) ?? .center
        VStack(alignment: alignment, spacing: CGFloat(spacing ?? 0.0)) {
            childrenViews(c)
        }
        .applyStyle(effectiveStyle(c), resolver: resolver)
    }

    @ViewBuilder
    private func childrenViews(_ c: UIComponent) -> some View {
        ForEach(Array((c.children ?? []).enumerated()), id: \.offset) { _, child in
            UIComponentView(component: child, resolver: resolver, stylesheet: stylesheet)
        }
    }

    // MARK: - Shape renderers

    @ViewBuilder
    private func renderRoundedRect(_ c: UIComponent) -> some View {
        let resolved = effectiveStyle(c)
        let cr = c.props?["cornerRadius"]?.doubleValue ?? resolved?.cornerRadius ?? 12
        if let fillValue = resolved?.fill {
            RoundedRectangle(cornerRadius: cr)
                .fill(resolver.resolveShapeStyle(fillValue))
                .applyStyle(withoutFill(resolved), resolver: resolver)
        } else {
            RoundedRectangle(cornerRadius: cr)
                .applyStyle(resolved, resolver: resolver)
        }
    }

    @ViewBuilder
    private func renderCapsule(_ c: UIComponent) -> some View {
        let resolved = effectiveStyle(c)
        if let fillValue = resolved?.fill {
            Capsule()
                .fill(resolver.resolveShapeStyle(fillValue))
                .applyStyle(withoutFill(resolved), resolver: resolver)
        } else {
            Capsule()
                .applyStyle(resolved, resolver: resolver)
        }
    }

    @ViewBuilder
    private func renderCircle(_ c: UIComponent) -> some View {
        let resolved = effectiveStyle(c)
        if let fillValue = resolved?.fill {
            Circle()
                .fill(resolver.resolveShapeStyle(fillValue))
                .applyStyle(withoutFill(resolved), resolver: resolver)
        } else {
            Circle()
                .applyStyle(resolved, resolver: resolver)
        }
    }

    // MARK: - Leaf renderers

    @ViewBuilder
    private func renderText(_ c: UIComponent) -> some View {
        let resolved = effectiveStyle(c)
        let rawContent = c.props?["content"]?.stringValue ?? ""
        let content = resolver.resolveString(rawContent)
        let isStruck: Bool = {
            guard let sv = resolved?.strikethrough else { return false }
            switch sv {
            case .bool(let b): return b
            case .string(let str): return resolver.resolveBool(str)
            default: return false
            }
        }()
        if isStruck {
            Text(content)
                .strikethrough(true)
                .applyTextStyle(resolved, resolver: resolver, text: content)
        } else {
            Text(content)
                .applyTextStyle(resolved, resolver: resolver, text: content)
        }
    }

    @ViewBuilder
    private func renderImage(_ c: UIComponent) -> some View {
        let rawName = c.props?["systemName"]?.stringValue ?? ""
        let name = resolver.resolveString(rawName)
        Image(systemName: name)
            .applyStyle(effectiveStyle(c), resolver: resolver)
    }

    // MARK: - ForEach renderer

    @ViewBuilder
    private func renderForEach(_ c: UIComponent) -> some View {
        if let spec = c.forEach {
            let items = resolver.resolveStrings(spec.dataBinding)
            ForEach(items, id: \.self) { item in
                let childResolver = resolver.childResolver(itemAlias: spec.itemAlias, value: item)
                ForEach(Array((c.children ?? []).enumerated()), id: \.offset) { _, child in
                    UIComponentView(component: child, resolver: childResolver, stylesheet: stylesheet)
                }
            }
        }
    }

    // MARK: - NativeComponent renderer (escape hatch for domain-specific views)

    @ViewBuilder
    private func renderNative(_ c: UIComponent) -> some View {
        let name = c.props?["name"]?.stringValue ?? ""
        switch name {
        case "CategoryPill":
            CategoryPill(
                category: resolver.resolveCategory(c.props?["category"]),
                color: resolver.resolveColor(c.props?["color"]?.stringValue ?? "$categoryColor")
            )
        case "PriorityDot":
            PriorityDot(priority: resolver.resolvePriority(c.props?["priority"]))
        case "CompletionBadge":
            NativeCompletionBadge(
                isCompleted: resolver.resolveBool(c.props?["isCompleted"]?.stringValue ?? "$task.isCompleted")
            )
        case "AssigneeStack":
            AssigneeStack(assignees: resolver.task.assignees)
        case "TagChip":
            TagChip(label: resolver.resolveString(c.props?["label"]?.stringValue ?? ""))
        case "MetaLabel":
            MetaLabel(
                symbol: c.props?["symbol"]?.stringValue ?? "",
                value: resolver.resolveString(c.props?["value"]?.stringValue ?? "")
            )
        case "ProgressBar":
            NativeProgressBar(
                progress: resolver.resolveDouble(c.props?["progress"]?.stringValue ?? "$task.progress"),
                color: resolver.resolveColor(c.props?["color"]?.stringValue ?? "$categoryColor")
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Alignment helpers

    private func hVAlignment(_ name: String?) -> Alignment? {
        switch name {
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

    private func hAlignment(_ name: String?) -> HorizontalAlignment? {
        switch name {
        case "leading":  return .leading
        case "center":   return .center
        case "trailing": return .trailing
        default:         return nil
        }
    }

    private func vAlignment(_ name: String?) -> VerticalAlignment? {
        switch name {
        case "top":      return .top
        case "center":   return .center
        case "bottom":   return .bottom
        default:         return nil
        }
    }

    // Returns a copy of StyleProps with fill cleared (fill is applied directly to shapes)
    private func withoutFill(_ style: StyleProps?) -> StyleProps? {
        guard var s = style else { return nil }
        s.fill = nil
        return s
    }
}

// MARK: - Native leaf views not in HeavyTaskRowView

struct NativeProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 6)
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * progress, height: 6)
            }
            .frame(height: 6)
        }
    }
}

struct NativeCompletionBadge: View {
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                .frame(width: 28, height: 28)
            Image(systemName: isCompleted ? "checkmark" : "circle.dotted")
                .font(.caption.weight(.bold))
                .foregroundStyle(isCompleted ? .green : .secondary)
        }
    }
}
