import SwiftUI
import Observation

// Central cache of compiled layouts. Receives server LayoutResponses,
// compiles them off the main thread, and publishes results to the UI.
// Cells show a skeleton while the first compile is in flight; subsequent
// launches skip the skeleton by warming from disk.
@Observable
@MainActor
final class LayoutCache {
    private(set) var layouts:  [String: CompiledLayout] = [:]
    private var versions:      [String: Int]            = [:]

    init() {
        warmFromDisk()
    }

    // Call for every LayoutResponse received from the server.
    // Skips stale responses; compiles and publishes fresher ones.
    func receive(_ response: LayoutResponse) {
        let id      = response.layoutID
        let version = response.version
        guard (versions[id] ?? -1) < version else { return }

        let root       = response.layout.root
        let stylesheet = response.stylesheet

        Swift.Task.detached(priority: .userInitiated) { [weak self] in
            let result = LayoutCompiler.compile(root, stylesheet: stylesheet)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.layouts[id]  = result
                self.versions[id] = version
            }
            await LayoutDiskCache.shared.save(response)
        }
    }

    func layout(for id: String) -> CompiledLayout? {
        layouts[id]
    }

    // Warm the cache from disk on launch so cells render immediately without
    // showing a skeleton, before the network fetch completes.
    private func warmFromDisk() {
        Swift.Task.detached(priority: .userInitiated) { [weak self] in
            let cached = await LayoutDiskCache.shared.loadAll()
            for response in cached {
                let id         = response.layoutID
                let version    = response.version
                let root       = response.layout.root
                let stylesheet = response.stylesheet
                let result     = LayoutCompiler.compile(root, stylesheet: stylesheet)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard (self.versions[id] ?? -1) < version else { return }
                    self.layouts[id]  = result
                    self.versions[id] = version
                }
            }
        }
    }
}
