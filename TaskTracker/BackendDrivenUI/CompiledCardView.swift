import SwiftUI

// Single-body card view using a pre-compiled layout from LayoutCache.
// body fires ONCE per new cell (same as HeavyTaskRowView).
// Shows a skeleton while the layout is compiling for the first time.
struct CompiledCardView: View, Equatable {
    let task:     Task
    let layoutID: String   // "task_card" | "task_compact" | …

    @Environment(LayoutCache.self) private var cache

    static func == (lhs: CompiledCardView, rhs: CompiledCardView) -> Bool {
        lhs.task == rhs.task
    }

    var body: some View {
        let _ = BodyEvalCounter.shared.compiledTick()
        if let layout = cache.layout(for: layoutID) {
            layout.build(TaskDataResolver(task: task))
        } else {
            CardSkeletonView()
        }
    }
}
