import SwiftUI

// Runtime counterpart of FeedCompiler: nothing is prepared at load time. A row's
// body walks the raw layout JSON and returns AnyView directly, so the whole tree
// still renders inside ONE body (like CompiledFeedRow), but the cost moves from
// launch to the first time each row appears. Parsed styles are memoised on first
// use so repeat rows don't re-parse colours and fonts.
@MainActor
final class FeedRuntime {
    let document: FeedDocument
    private var resolved: [String: ResolvedFeedStyle] = [:]

    init(_ document: FeedDocument) {
        self.document = document
    }

    func render(_ n: FeedNode, _ d: [String: FeedData]) -> AnyView {
        let style = n.styleId.flatMap(style(for:))
        let raw = content(n, style: style, d)
        guard let style else { return raw }
        return raw.compiledFeedStyle(style)
    }

    private func style(for id: String) -> ResolvedFeedStyle? {
        if let hit = resolved[id] { return hit }
        guard let s = document.styles[id] else { return nil }
        let r = ResolvedFeedStyle(s)
        resolved[id] = r
        return r
    }

    private func content(_ n: FeedNode, style: ResolvedFeedStyle?, _ d: [String: FeedData]) -> AnyView {
        let spacing = n.spacing.map { CGFloat($0) }
        let value = n.dataId.flatMap { d[$0] }
        let kids = n.children ?? []

        switch n.type {
        case .vstack:
            return AnyView(VStack(alignment: FeedParse.horizontal(n.alignment ?? "leading"), spacing: spacing) {
                ForEach(kids.indices, id: \.self) { self.render(kids[$0], d) }
            })
        case .hstack:
            return AnyView(HStack(alignment: FeedParse.vertical(n.alignment), spacing: spacing) {
                ForEach(kids.indices, id: \.self) { self.render(kids[$0], d) }
            })
        case .zstack:
            return AnyView(ZStack(alignment: FeedParse.alignment(n.alignment)) {
                ForEach(kids.indices, id: \.self) { self.render(kids[$0], d) }
            })
        case .label:
            return AnyView(Text(value?.text ?? ""))
        case .image:
            let sized = style?.width != nil || style?.height != nil
            let fill = n.styleId.flatMap { document.styles[$0]?.contentMode } == "fill"
            return AnyView(FeedCompiler.image(value, sized: sized, fill: fill))
        case .spacer:
            return AnyView(Spacer(minLength: 0))
        case .divider:
            return AnyView(Divider())
        case .progress:
            return AnyView(ProgressView(value: min(max(value?.value ?? 0, 0), 1)))
        case .carousel:
            guard let template = n.template else { return AnyView(EmptyView()) }
            let entries = value?.items ?? []
            return AnyView(
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing ?? 12) {
                        ForEach(entries.indices, id: \.self) { self.render(template, entries[$0]) }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, CGFloat(n.inset ?? 0), for: .scrollContent)
            )
        case .grid:
            guard let template = n.template else { return AnyView(EmptyView()) }
            let entries = value?.items ?? []
            let s = spacing ?? 12
            let columns = Array(repeating: GridItem(.flexible(), spacing: s, alignment: .top),
                                count: max(n.columns ?? 2, 1))
            return AnyView(
                LazyVGrid(columns: columns, alignment: .leading, spacing: s) {
                    ForEach(entries.indices, id: \.self) { self.render(template, entries[$0]) }
                }
            )
        case .vlist:
            guard let template = n.template else { return AnyView(EmptyView()) }
            let entries = value?.items ?? []
            return AnyView(
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: spacing ?? 0) {
                        ForEach(entries.indices, id: \.self) { self.render(template, entries[$0]) }
                    }
                }
            )
        }
    }
}

// One body per feed row; the layout is walked here, at render time.
struct RuntimeFeedRow: View, Equatable {
    let item: FeedItem
    let layout: FeedNode
    let runtime: FeedRuntime

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.item.id == rhs.item.id }

    var body: some View {
        let _ = BodyEvalCounter.shared.compiledTick()
        runtime.render(layout, item.data)
    }
}

struct RuntimeFeedListView: View {
    let runtime: FeedRuntime

    var body: some View {
        List(runtime.document.items) { item in
            if let layout = runtime.document.layouts[item.layoutId] {
                RuntimeFeedRow(item: item, layout: layout, runtime: runtime)
                    .equatable()
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}
