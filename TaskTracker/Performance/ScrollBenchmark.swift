import SwiftUI
import QuartzCore

// Records frame pacing for each scroll gesture (touch-down → deceleration ends) and
// appends one JSON line per gesture to Documents/scroll_bench.jsonl.
@MainActor
final class ScrollBenchmark {
    static let shared = ScrollBenchmark()
    private init() {}

    private var displayLink: CADisplayLink?
    private var label = ""
    private var startTime: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var frames = 0
    private var droppedFrames = 0
    private var hitchTime: CFTimeInterval = 0
    private var maxFrame: CFTimeInterval = 0
    private var evalsAtStart = 0

    static var logURL: URL {
        URL.documentsDirectory.appending(path: "scroll_bench.jsonl")
    }

    func begin(label: String) {
        guard displayLink == nil else { return }
        self.label = label
        frames = 0; droppedFrames = 0; hitchTime = 0; maxFrame = 0
        lastTimestamp = 0; startTime = 0
        evalsAtStart = Self.totalEvals()
        let dl = CADisplayLink(target: BenchLinkProxy(), selector: #selector(BenchLinkProxy.tick(_:)))
        dl.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }

    func end() {
        guard let dl = displayLink else { return }
        dl.invalidate()
        displayLink = nil
        let duration = lastTimestamp - startTime
        guard frames > 0, duration > 0 else { return }

        let record: [String: Any] = [
            "label": label,
            "durationMs": duration * 1000,
            "frames": frames,
            "fps": Double(frames) / duration,
            "droppedFrames": droppedFrames,
            "hitchTimeMs": hitchTime * 1000,
            "hitchRatioMsPerS": hitchTime * 1000 / duration,
            "maxFrameMs": maxFrame * 1000,
            "bodyEvals": Self.totalEvals() - evalsAtStart,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
        let line = data + Data("\n".utf8)
        if let handle = try? FileHandle(forWritingTo: Self.logURL) {
            handle.seekToEndOfFile(); handle.write(line); try? handle.close()
        } else {
            try? line.write(to: Self.logURL)
        }
        print("[ScrollBench] \(String(decoding: data, as: UTF8.self))")
    }

    fileprivate func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard lastTimestamp != 0 else { startTime = link.timestamp; return }
        frames += 1
        let delta = link.timestamp - lastTimestamp
        let expected = link.targetTimestamp - link.timestamp
        maxFrame = max(maxFrame, delta)
        // Any frame that overruns its budget by more than half a frame is a hitch.
        if expected > 0, delta > expected * 1.5 {
            droppedFrames += Int((delta / expected).rounded()) - 1
            hitchTime += delta - expected
        }
    }

    private static func totalEvals() -> Int {
        let s = BodyEvalCounter.shared.snapshot()
        return s.native + s.bdui + s.nodes + s.compiled
    }
}

private final class BenchLinkProxy {
    @objc func tick(_ link: CADisplayLink) {
        MainActor.assumeIsolated { ScrollBenchmark.shared.tick(link) }
    }
}

extension View {
    func scrollBenchmark(label: String) -> some View {
        onScrollPhaseChange { _, phase in
            if phase == .idle {
                ScrollBenchmark.shared.end()
            } else {
                ScrollBenchmark.shared.begin(label: label)
            }
        }
    }
}
