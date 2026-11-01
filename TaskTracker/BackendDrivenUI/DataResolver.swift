import SwiftUI

struct TaskDataResolver {
    let task: Task
    private var context: [String: Any]

    init(task: Task, extraContext: [String: Any] = [:]) {
        self.task = task
        var ctx: [String: Any] = [
            "task.title":           task.title,
            "task.description":     task.description,
            "task.isCompleted":     task.isCompleted,
            "task.progress":        task.progress,
            "task.tags":            task.tags,
            "task.dueDate":         task.dueDate,
            "task.commentCount":    task.commentCount,
            "task.attachmentCount": task.attachmentCount,
            "task.coverSymbol":     task.coverSymbol,
            "task.priority":        task.priority.rawValue,
            "task.category":        task.category.rawValue,
            "categoryColor":        Self.categoryColor(for: task.category),
        ]
        ctx.merge(extraContext) { _, new in new }
        self.context = ctx
    }

    func childResolver(itemAlias: String, value: Any) -> TaskDataResolver {
        TaskDataResolver(task: task, extraContext: [itemAlias: value])
    }

    // MARK: - Typed resolution

    func resolveString(_ expr: String) -> String {
        guard expr.hasPrefix("$") else { return expr }
        let (key, mods) = parseExpression(expr)
        let base = context[key]
        var result = stringify(base)
        for mod in mods {
            result = applyStringModifier(result, modifier: mod, base: base)
        }
        return result
    }

    func resolveBool(_ expr: String) -> Bool {
        guard expr.hasPrefix("$") else { return Bool(expr) ?? false }
        let (key, _) = parseExpression(expr)
        if let b = context[key] as? Bool { return b }
        return false
    }

    func resolveDouble(_ expr: String) -> Double {
        guard expr.hasPrefix("$") else { return Double(expr) ?? 0 }
        let (key, _) = parseExpression(expr)
        if let d = context[key] as? Double { return d }
        return 0
    }

    func resolveColor(_ expr: String) -> Color {
        guard expr.hasPrefix("$") else { return namedColor(expr) }
        let (key, mods) = parseExpression(expr)
        var color = context[key] as? Color ?? .primary
        for mod in mods {
            if mod.hasPrefix("opacity:"), let val = Double(mod.dropFirst("opacity:".count)) {
                color = color.opacity(val)
            }
        }
        return color
    }

    func resolveStrings(_ expr: String) -> [String] {
        guard expr.hasPrefix("$") else { return [] }
        let (key, _) = parseExpression(expr)
        if let arr = context[key] as? [String] { return arr }
        return []
    }

    func resolveCategory(_ value: JSONValue?) -> TaskCategory {
        guard let str = value.flatMap({ resolveJSONValue($0).stringValue }) else { return task.category }
        return TaskCategory(rawValue: str) ?? task.category
    }

    func resolvePriority(_ value: JSONValue?) -> TaskPriority {
        guard let str = value.flatMap({ resolveJSONValue($0).stringValue }) else { return task.priority }
        return TaskPriority(rawValue: str) ?? task.priority
    }

    // Resolves a JSONValue — handles binding strings, conditionals, and literals
    func resolveJSONValue(_ value: JSONValue) -> JSONValue {
        switch value {
        case .string(let s) where s.hasPrefix("$"):
            return .string(resolveString(s))
        case .object(let obj) where obj["type"]?.stringValue == "conditional":
            guard let condExpr = obj["condition"]?.stringValue else { return .null }
            let condition = resolveBool(condExpr)
            let branch = condition ? obj["true"] : obj["false"]
            return branch.map { resolveJSONValue($0) } ?? .null
        default:
            return value
        }
    }

    func resolveShapeStyle(_ value: JSONValue) -> AnyShapeStyle {
        let resolved = resolveJSONValue(value)
        if let s = resolved.stringValue {
            return AnyShapeStyle(namedShapeStyle(s))
        }
        if let obj = resolved.objectValue, obj["type"]?.stringValue == "linearGradient" {
            let colors = obj["colors"]?.arrayValue?.compactMap { v -> Color? in
                guard let s = v.stringValue else { return nil }
                return resolveColor(s)
            } ?? []
            let start = unitPoint(obj["startPoint"]?.stringValue)
            let end = unitPoint(obj["endPoint"]?.stringValue)
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: start, endPoint: end))
        }
        return AnyShapeStyle(Color.primary)
    }

    // MARK: - Private helpers

    private func parseExpression(_ expr: String) -> (key: String, modifiers: [String]) {
        let stripped = String(expr.dropFirst()) // remove "$"
        let parts = stripped.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
        return (parts[0], Array(parts.dropFirst()))
    }

    private func stringify(_ value: Any?) -> String {
        switch value {
        case let s as String:  return s
        case let i as Int:     return "\(i)"
        case let d as Double:  return "\(Int(d * 100))%"
        case let b as Bool:    return "\(b)"
        default:               return ""
        }
    }

    private func applyStringModifier(_ current: String, modifier: String, base: Any?) -> String {
        if modifier == "percent", let d = base as? Double {
            return "\(Int(d * 100))%"
        }
        if modifier == "toString" { return current }
        return current
    }

    private func namedColor(_ name: String) -> Color {
        switch name {
        case "primary":     return .primary
        case "secondary":   return .secondary
        case "red":         return .red
        case "orange":      return .orange
        case "blue":        return .blue
        case "green":       return .green
        case "purple":      return .purple
        case "teal":        return .teal
        case "indigo":      return .indigo
        case "pink":        return .pink
        case "yellow":      return .yellow
        case "mint":        return .mint
        case "cyan":        return .cyan
        default:            return .primary
        }
    }

    private func namedShapeStyle(_ name: String) -> AnyShapeStyle {
        switch name {
        case "secondary": return AnyShapeStyle(.secondary)
        default:          return AnyShapeStyle(namedColor(name))
        }
    }

    private func unitPoint(_ name: String?) -> UnitPoint {
        switch name {
        case "topLeading":    return .topLeading
        case "topTrailing":   return .topTrailing
        case "bottomLeading": return .bottomLeading
        case "bottomTrailing": return .bottomTrailing
        case "top":    return .top
        case "bottom": return .bottom
        case "leading": return .leading
        case "trailing": return .trailing
        default:       return .center
        }
    }

    static func categoryColor(for category: TaskCategory) -> Color {
        switch category {
        case .design:      return .purple
        case .engineering: return .blue
        case .qa:          return .green
        case .release:     return .orange
        case .infra:       return .teal
        }
    }
}
