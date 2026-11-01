import SwiftUI

// MARK: - Heavy card cell demonstrating ZStack / HStack / VStack combinations

struct HeavyTaskRowView: View, Equatable {
    let task: Task
    var overlayMode: OverlayMode = .hundredDataLoops

    static func == (lhs: HeavyTaskRowView, rhs: HeavyTaskRowView) -> Bool {
        lhs.task == rhs.task && lhs.overlayMode == rhs.overlayMode
    }

    var body: some View {
        let _ = BodyEvalCounter.shared.nativeTick()

        // ── OUTER ZSTACK ─────────────────────────────────────────────────
        // Layer 0: gradient card background
        // Layer 1: decorative SF Symbol watermark (background image pattern)
        // Layer 2: all content
        ZStack(alignment: .topLeading) {

            // Layer 0 — gradient background card
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.18), categoryColor.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Layer 2 — large watermark symbol (bg "image")
            Image(systemName: task.coverSymbol)
                .font(.system(size: 96))
                .foregroundStyle(categoryColor.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(12)

            // Layer 2 — main content VStack
            VStack(alignment: .leading, spacing: 10) {

                // ── TOP ROW: category pill + priority dot + completion toggle ──
                // Pattern: HStack containing small sub-views
                HStack(spacing: 6) {
                    CategoryPill(category: task.category, color: categoryColor)

                    PriorityDot(priority: task.priority)

                    Spacer()

                    // Completion badge — another ZStack (icon over circle bg)
                    ZStack {
                        Circle()
                            .fill(task.isCompleted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Image(systemName: task.isCompleted ? "checkmark" : "circle.dotted")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                    }
                }

                // ── TITLE + DESCRIPTION VStack ────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(1)

                    Text(task.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── PROGRESS ROW: label + bar + percent ───────────────────
                // Pattern: HStack wrapping a custom ZStack progress bar
                HStack(spacing: 8) {
                    Text("Progress")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    // ZStack for the progress track + fill overlay
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)
                        GeometryReader { geo in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [categoryColor, categoryColor.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * task.progress, height: 6)
                        }
                        .frame(height: 6)
                    }

                    Text("\(Int(task.progress * 100))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(categoryColor)
                        .frame(width: 32, alignment: .trailing)
                }

                // ── TAGS ROW ──────────────────────────────────────────────
                // Pattern: HStack of tag pills
                HStack(spacing: 6) {
                    ForEach(task.tags, id: \.self) { tag in
                        TagChip(label: tag)
                    }
                    Spacer()
                }

                // ── FOOTER ROW ────────────────────────────────────────────
                // Pattern: HStack mixing avatar stack + metadata labels
                HStack(alignment: .center, spacing: 12) {

                    // Overlapping avatar stack (nested ZStack + HStack offset trick)
                    AssigneeStack(assignees: task.assignees)

                    Spacer()

                    // Metadata: comments, attachments, due date
                    // Pattern: HStack of label pairs
                    HStack(spacing: 10) {
                        MetaLabel(symbol: "bubble.right", value: "\(task.commentCount)")
                        MetaLabel(symbol: "paperclip", value: "\(task.attachmentCount)")
                        MetaLabel(symbol: "calendar", value: task.dueDate)
                    }
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(overlayContent, alignment: .topLeading)
        .shadow(color: categoryColor.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: - Overlay variants

    @ViewBuilder
    private var overlayContent: some View {
        switch overlayMode {

        // ── MODE A: 100 real SwiftUI Text views ───────────────────────────
        // Each iteration produces a Text struct → view tree node → layout pass.
        // SwiftUI must allocate, diff, and lay out all 100 on every body call.
        case .hundredViews:
            ZStack {
                ForEach(0..<100, id: \.self) { i in
                    Text("view \(i) · \(task.title)")
                        .font(.system(size: 8))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(4)

        // ── MODE B: 100 data iterations, zero new views ───────────────────
        // The loop runs 100 times in pure Swift — string work, no view structs.
        // SwiftUI sees exactly ONE Text node. Layout is trivial.
        // This is the UIKit analogy: iterate data, update a single label.
        case .hundredDataLoops:
            let summary: String = {
                var result = ""
                for i in 0..<100 {
                    // same work as Mode A but produces NO view — just Swift string ops
                    result = "loop \(i) · \(task.title)"
                }
                return result // only the last value matters; the rest is pure CPU
            }()
            Text("Data loops done · last: \(summary)")
                .font(.system(size: 8))
                .lineLimit(1)
                .padding(4)

        case .none:
            EmptyView()
        }
    }

    private var categoryColor: Color {
        switch task.category {
        case .design:      .purple
        case .engineering: .blue
        case .qa:          .green
        case .release:     .orange
        case .infra:       .teal
        }
    }
}

// MARK: - Sub-views (each is a small reusable building block)

// ZStack: pill with icon + text layered on a background capsule
struct CategoryPill: View {
    let category: TaskCategory
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: categorySymbol)
                .font(.caption2)
            Text(category.rawValue)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private var categorySymbol: String {
        switch category {
        case .design:      "paintbrush"
        case .engineering: "hammer"
        case .qa:          "checkmark.seal"
        case .release:     "arrow.up.circle"
        case .infra:       "server.rack"
        }
    }
}

// ZStack: coloured ring around a dot
struct PriorityDot: View {
    let priority: TaskPriority

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(dotColor.opacity(0.4), lineWidth: 1.5)
                .frame(width: 16, height: 16)
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        }
    }

    private var dotColor: Color {
        switch priority {
        case .high:   .red
        case .medium: .orange
        case .low:    .blue
        }
    }
}

// Simple text capsule chip
struct TagChip: View {
    let label: String

    var body: some View {
        Text("#\(label)")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.secondary.opacity(0.1))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Overlapping avatar circles — ZStack + offset per avatar
struct AssigneeStack: View {
    let assignees: [Assignee]
    private let size: CGFloat = 26
    private let overlap: CGFloat = 10

    var body: some View {
        // ZStack + manual x-offset produces the overlapping pile
        ZStack {
            ForEach(Array(assignees.prefix(3).enumerated()), id: \.offset) { index, assignee in
                ZStack {
                    Circle()
                        .fill(assignee.avatarColor.opacity(0.85))
                        .frame(width: size, height: size)
                        // White ring separator — another ZStack layer
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    Text(assignee.initials)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: CGFloat(index) * (size - overlap))
            }
        }
        // Reserve the full width so the stack doesn't collapse
        .frame(
            width: size + CGFloat(min(assignees.count, 3) - 1) * (size - overlap),
            height: size,
            alignment: .leading
        )
    }
}

// HStack: symbol icon + text value
struct MetaLabel: View {
    let symbol: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(value)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Task.mockData) { task in
                HeavyTaskRowView(task: task)
                    .equatable()
            }
        }
        .padding()
    }
}
