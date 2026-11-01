import SwiftUI
import Playgrounds

enum OverlayMode: String, CaseIterable {
    case hundredViews = "100 Views"
    case hundredDataLoops = "100 Data Loops"
    case none = "None"
}

enum RenderMode: String, CaseIterable {
    case native    = "Native"
    case bdui      = "BDUI"
    case compiled  = "Compiled"
    case feed      = "Feed"
    case feedCompiled = "FeedC"
    case feedRuntime  = "FeedR"

    var isFeed: Bool { self == .feed || self == .feedCompiled || self == .feedRuntime }

    var symbol: String {
        switch self {
        case .native:       return "swift"
        case .bdui:         return "server.rack"
        case .compiled:     return "bolt"
        case .feed:         return "list.bullet.indent"
        case .feedCompiled: return "bolt.horizontal"
        case .feedRuntime:  return "play.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .native:       return "Hand-written SwiftUI"
        case .bdui:         return "Interpreted, view per node"
        case .compiled:     return "Precompiled card"
        case .feed:         return "Interpreted feed"
        case .feedCompiled: return "Feed compiled at load"
        case .feedRuntime:  return "Feed walked in row body"
        }
    }

    var tint: Color {
        switch self {
        case .native:       return .orange
        case .bdui:         return .blue
        case .compiled:     return .green
        case .feed:         return .pink
        case .feedCompiled: return .purple
        case .feedRuntime:  return .teal
        }
    }
}

struct PerformanceTestingView: View {
    @State private var tasks: [Task] = Task.mockData
    @State private var overlayMode: OverlayMode = .none
    @State private var renderMode: RenderMode =
        UserDefaults.standard.string(forKey: "renderMode").flatMap(RenderMode.init(rawValue:)) ?? .native
    @State private var perf = PerformanceMonitor()

    @Environment(LayoutCache.self) private var layoutCache

    // Layout / styles / data feed — decoded once from the bundle
    private static let feedDocument = FeedLoader.load(named: "feed_layouts")
    private static let compiledFeed = feedDocument.map(CompiledFeed.init)
    // No load-time work: layouts are walked lazily inside each row's body
    private static let feedRuntime = feedDocument.map(FeedRuntime.init)

    var body: some View {
        NavigationStack {
            Group {
            if renderMode == .feed, let feed = Self.feedDocument {
                FeedListView(document: feed)
                    .scrollBenchmark(label: renderMode.rawValue)
            } else if renderMode == .feedCompiled, let feed = Self.compiledFeed {
                CompiledFeedListView(feed: feed)
                    .scrollBenchmark(label: renderMode.rawValue)
            } else if renderMode == .feedRuntime, let runtime = Self.feedRuntime {
                RuntimeFeedListView(runtime: runtime)
                    .scrollBenchmark(label: renderMode.rawValue)
            } else {
            List(tasks) { task in
                Group {
                    switch renderMode {
                    case .native:
                        HeavyTaskRowView(task: task, overlayMode: overlayMode)
                            .equatable()
                    case .bdui:
                        BackendDrivenTaskRowView(task: task)
                            .equatable()
                    case .compiled, .feed, .feedCompiled, .feedRuntime:
                        CompiledCardView(task: task, layoutID: task.cardLayoutID)
                            .equatable()
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollBenchmark(label: renderMode.rawValue)
            }
            }
            .navigationTitle(renderMode.isFeed ? "Feed" : "My Tasks")
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    RenderModeSwitcher(selection: $renderMode)
                    PerfStatsBar(perf: perf, renderMode: renderMode)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if renderMode == .native {
                        Picker("Mode", selection: $overlayMode) {
                            ForEach(OverlayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Reset Stats") { perf.reset() }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Change Cell 0 Title") {
                            tasks[0].title = "UPDATED: \(Int.random(in: 1...999))"
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task {
            let responses = await LayoutService.fetchAll()
            for response in responses {
                layoutCache.receive(response)
            }
        }
        .onChange(of: renderMode) {
            perf.reset()
            UserDefaults.standard.set(renderMode.rawValue, forKey: "renderMode")
        }
        .onAppear { perf.start() }
        .onDisappear { perf.stop() }
    }
}

// MARK: - Render mode switcher

struct RenderModeSwitcher: View {
    @Binding var selection: RenderMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RenderMode.allCases, id: \.self) { mode in
                            chip(mode)
                                .id(mode)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: selection) {
                    withAnimation { proxy.scrollTo(selection, anchor: .center) }
                }
            }
            Text(selection.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(_ mode: RenderMode) -> some View {
        let selected = mode == selection
        return Button {
            withAnimation(.snappy) { selection = mode }
        } label: {
            Label(mode.rawValue, systemImage: mode.symbol)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? .white : mode.tint)
                .background(selected ? mode.tint : mode.tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Performance stats bar

struct PerfStatsBar: View {
    var perf: PerformanceMonitor
    let renderMode: RenderMode

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                StatChip(
                    label: "FPS",
                    value: String(format: "%.0f", perf.fps),
                    color: fpsColor
                )
                switch renderMode {
                case .native:
                    StatChip(label: "Row evals", value: "\(perf.nativeEvals)", color: .orange)
                case .bdui:
                    StatChip(label: "Row evals", value: "\(perf.bduiEvals)", color: .blue)
                    StatChip(label: "Node evals", value: "\(perf.nodeEvals)", color: .purple)
                case .compiled:
                    StatChip(label: "Row evals", value: "\(perf.compiledEvals)", color: .green)
                    StatChip(label: "Nodes", value: "0", color: .green)
                case .feed:
                    StatChip(label: "Node evals", value: "\(perf.nodeEvals)", color: .pink)
                case .feedCompiled, .feedRuntime:
                    StatChip(label: "Row evals", value: "\(perf.compiledEvals)", color: renderMode.tint)
                }
                StatChip(label: "Evals/s", value: "\(perf.evalsPerSecond)", color: .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            Divider()
        }
        .background(.bar)
    }

    private var fpsColor: Color {
        if perf.fps >= 55 { return .green }
        if perf.fps >= 30 { return .orange }
        return .red
    }
}

private struct StatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.callout, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PerformanceTestingView()
}

#Playground {
    _ = 1 + 2
}
