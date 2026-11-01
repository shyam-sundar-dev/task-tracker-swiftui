import SwiftUI

struct BackendDrivenTaskRowView: View, Equatable {
    let task: Task

    @Environment(\.cardComponentDefinition) private var definition

    static func == (lhs: BackendDrivenTaskRowView, rhs: BackendDrivenTaskRowView) -> Bool {
        lhs.task == rhs.task
    }

    var body: some View {
        let _ = BodyEvalCounter.shared.bduiTick()
        if let def = definition {
            UIComponentView(
                component: def.root,
                resolver: TaskDataResolver(task: task),
                stylesheet: def.stylesheet ?? [:]
            )
        } else {
            // Fallback while JSON hasn't loaded
            HeavyTaskRowView(task: task)
        }
    }
}

// MARK: - Environment keys

private struct CardComponentDefinitionKey: EnvironmentKey {
    static let defaultValue: ComponentDefinition? = nil
}

extension EnvironmentValues {
    var cardComponentDefinition: ComponentDefinition? {
        get { self[CardComponentDefinitionKey.self] }
        set { self[CardComponentDefinitionKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    let definition = try? ComponentLoader.load(named: "task_card_layout")
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Task.mockData.prefix(5)) { task in
                BackendDrivenTaskRowView(task: task)
                    .equatable()
            }
        }
        .padding()
    }
    .environment(\.cardComponentDefinition, definition)
}
