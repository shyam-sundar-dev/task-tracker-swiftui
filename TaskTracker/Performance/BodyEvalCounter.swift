import Foundation

// Thread-safe body-evaluation counters. All SwiftUI body calls happen on the main
// thread, so @MainActor isolation is both correct and avoids synchronization overhead.
@MainActor
final class BodyEvalCounter {
    static let shared = BodyEvalCounter()
    private init() {}

    // Incremented by HeavyTaskRowView.body
    private(set) var native: Int = 0
    // Incremented by BackendDrivenTaskRowView.body (interpreted renderer)
    private(set) var bdui: Int = 0
    // Incremented by every UIComponentView.body (28 per BDUI cell)
    private(set) var nodes: Int = 0
    // Incremented by CompiledCardView.body (compiled renderer — 1 per cell)
    private(set) var compiled: Int = 0

    func nativeTick()   { native += 1 }
    func bduiTick()     { bdui += 1 }
    func nodeTick()     { nodes += 1 }
    func compiledTick() { compiled += 1 }

    func reset() {
        native = 0
        bdui = 0
        nodes = 0
        compiled = 0
    }

    // Snapshot for display — called from PerformanceMonitor on a timer tick
    func snapshot() -> (native: Int, bdui: Int, nodes: Int, compiled: Int) {
        (native, bdui, nodes, compiled)
    }
}
