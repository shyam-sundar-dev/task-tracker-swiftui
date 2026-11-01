import SwiftUI
import Observation
import QuartzCore

@Observable
@MainActor
final class PerformanceMonitor {
    private(set) var fps: Double = 0
    private(set) var nativeEvals: Int = 0
    private(set) var bduiEvals: Int = 0
    private(set) var nodeEvals: Int = 0
    private(set) var compiledEvals: Int = 0
    private(set) var evalsPerSecond: Int = 0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastEvalsTotal: Int = 0

    private let sampleInterval: CFTimeInterval = 0.5

    func start() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(monitor: self)
        let dl = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func reset() {
        BodyEvalCounter.shared.reset()
        fps = 0
        nativeEvals = 0
        bduiEvals = 0
        nodeEvals = 0
        compiledEvals = 0
        evalsPerSecond = 0
        lastEvalsTotal = 0
        frameCount = 0
        lastTimestamp = 0
    }

    fileprivate func handleTick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        guard elapsed >= sampleInterval else { return }

        fps = Double(frameCount) / elapsed

        let snap = BodyEvalCounter.shared.snapshot()
        nativeEvals = snap.native
        bduiEvals = snap.bdui
        nodeEvals = snap.nodes
        compiledEvals = snap.compiled

        let total = snap.native + snap.bdui + snap.nodes + snap.compiled
        evalsPerSecond = Int(Double(total - lastEvalsTotal) / elapsed)
        lastEvalsTotal = total

        frameCount = 0
        lastTimestamp = link.timestamp
    }
}

private final class DisplayLinkProxy: @unchecked Sendable {
    weak var monitor: PerformanceMonitor?
    init(monitor: PerformanceMonitor) { self.monitor = monitor }

    @objc func tick(_ link: CADisplayLink) {
        Swift.Task { @MainActor [weak self] in
            self?.monitor?.handleTick(link)
        }
    }
}
