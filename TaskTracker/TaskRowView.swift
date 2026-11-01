import SwiftUI

struct TaskRowView: View, Equatable {
    let task: Task

    // Equatable conformance: two TaskRowViews are equal when their task data is equal.
    // .equatable() uses this to skip body when nothing changed.
    static func == (lhs: TaskRowView, rhs: TaskRowView) -> Bool {
        lhs.task == rhs.task
    }

    var body: some View {
        let _ = Self._printChanges()
        let _ = print(task.id)
        HStack(alignment: .top, spacing: 12) {
            
            // Completion indicator
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? .green : .secondary)
                .font(.title2)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                Text(task.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    PriorityBadge(priority: task.priority)

                    Label(task.dueDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Priority Badge (another small reusable piece)

private struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        Text(priority.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch priority {
        case .high:   .red
        case .medium: .orange
        case .low:    .blue
        }
    }
}

#Preview {
    List {
        TaskRowView(task: Task.mockData[0])
        TaskRowView(task: Task.mockData[2])
    }
}
