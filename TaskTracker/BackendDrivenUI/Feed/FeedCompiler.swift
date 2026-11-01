import SwiftUI

// Compiled counterpart of FeedNodeView. Each layout is walked once at load time:
// styles are resolved and parsed (fonts, colours, alignments) up front and every node
// becomes a closure. A feed row then renders its whole tree inside ONE body — the same
// cost model as CompiledCardView — instead of one FeedNodeView body per node.
typealias FeedBuilder = ([String: FeedData]) -> AnyView

struct CompiledFeed {
    let layouts: [String: FeedBuilder]
    let items: [FeedItem]

    init(_ doc: FeedDocument) {
        layouts = doc.layouts.mapValues { FeedCompiler.node($0, styles: doc.styles) }
        items = doc.items
    }
}

// FeedStyle with every string already parsed into its SwiftUI value.
struct ResolvedFeedStyle {
    let font: Font?
    let foreground: Color?
    let lineLimit: Int?
    let textAlignment: TextAlignment?
    let strikethrough: Bool
    let uppercase: Bool
    let paddingH: CGFloat
    let paddingV: CGFloat
    let width: CGFloat?
    let height: CGFloat?
    let fillWidth: Bool
    let frameAlignment: Alignment
    let cornerRadius: CGFloat
    let gradient: LinearGradient?
    let background: Color?
    let border: Color?
    let borderWidth: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let opacity: Double

    init(_ s: FeedStyle) {
        font = FeedParse.font(s)
        foreground = FeedParse.color(s.foreground)
        lineLimit = s.lineLimit
        textAlignment = s.textAlignment.map(FeedParse.textAlignment)
        strikethrough = s.strikethrough ?? false
        uppercase = s.uppercase ?? false
        paddingH = CGFloat(s.paddingH ?? s.padding ?? 0)
        paddingV = CGFloat(s.paddingV ?? s.padding ?? 0)
        width = s.width.map { CGFloat($0) }
        height = s.height.map { CGFloat($0) }
        fillWidth = s.fillWidth == true
        frameAlignment = FeedParse.alignment(s.frameAlignment)
        cornerRadius = CGFloat(s.cornerRadius ?? 0)
        let stops = s.gradient?.compactMap(FeedParse.color) ?? []
        gradient = stops.count > 1
            ? LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing) : nil
        background = FeedParse.color(s.background)
        border = FeedParse.color(s.borderColor)
        borderWidth = CGFloat(s.borderWidth ?? 1)
        shadowColor = FeedParse.color(s.shadowColor) ?? .black.opacity(0.12)
        shadowRadius = CGFloat(s.shadowRadius ?? 0)
        opacity = s.opacity ?? 1
    }
}

// Applies only the properties a style declares — no zero-radius shadows or
// clip shapes on nodes that don't need them (those force extra render passes).
extension View {
    func compiledFeedStyle(_ s: ResolvedFeedStyle) -> AnyView {
        AnyView(feedBox(s, AnyView(feedTypography(s))))
    }

    private func feedTypography(_ s: ResolvedFeedStyle) -> some View {
        self
            .ifLet(s.font) { $0.font($1) }
            .ifLet(s.foreground) { $0.foregroundStyle($1).tint($1) }
            .ifLet(s.lineLimit) { $0.lineLimit($1) }
            .ifLet(s.textAlignment) { $0.multilineTextAlignment($1) }
            .ifTrue(s.strikethrough) { $0.strikethrough() }
            .ifTrue(s.uppercase) { $0.textCase(.uppercase) }
    }

    private func feedBox<V: View>(_ s: ResolvedFeedStyle, _ content: V) -> some View {
        content
            .ifTrue(s.paddingH > 0 || s.paddingV > 0) {
                $0.padding(.horizontal, s.paddingH).padding(.vertical, s.paddingV)
            }
            .ifTrue(s.width != nil || s.height != nil) {
                $0.frame(width: s.width, height: s.height, alignment: s.frameAlignment)
            }
            .ifTrue(s.fillWidth) { $0.frame(maxWidth: .infinity, alignment: s.frameAlignment) }
            .ifLet(s.gradient) { $0.background($1) }
            .ifTrue(s.gradient == nil && s.background != nil) { $0.background(s.background!) }
            .ifLet(s.border) {
                $0.overlay(RoundedRectangle(cornerRadius: s.cornerRadius).strokeBorder($1, lineWidth: s.borderWidth))
            }
            .ifTrue(s.cornerRadius > 0) { $0.clipShape(RoundedRectangle(cornerRadius: s.cornerRadius)) }
            // Interpreted renderer always clipped; keep that for fixed frames so overflow matches
            .ifTrue(s.cornerRadius == 0 && (s.width != nil || s.height != nil)) { $0.clipped() }
            .ifTrue(s.shadowRadius > 0) { $0.shadow(color: s.shadowColor, radius: s.shadowRadius, y: s.shadowRadius / 2) }
            .ifTrue(s.opacity < 1) { $0.opacity(s.opacity) }
    }
}

extension View {
    @ViewBuilder
    func ifTrue<V: View>(_ condition: Bool, _ transform: (Self) -> V) -> some View {
        if condition { transform(self) } else { self }
    }
}

enum FeedCompiler {
    static func node(_ n: FeedNode, styles: [String: FeedStyle]) -> FeedBuilder {
        let style = n.styleId.flatMap { styles[$0] }.map(ResolvedFeedStyle.init)
        let raw = content(n, style: style, styles: styles)
        guard let style else { return raw }
        return { data in raw(data).compiledFeedStyle(style) }
    }

    private static func content(_ n: FeedNode, style: ResolvedFeedStyle?, styles: [String: FeedStyle]) -> FeedBuilder {
        let spacing = n.spacing.map { CGFloat($0) }
        let dataId = n.dataId ?? ""
        let kids = (n.children ?? []).map { node($0, styles: styles) }
        let template = n.template.map { node($0, styles: styles) }

        switch n.type {
        case .vstack:
            let a = FeedParse.horizontal(n.alignment ?? "leading")
            return { d in AnyView(VStack(alignment: a, spacing: spacing) { build(kids, d) }) }
        case .hstack:
            let a = FeedParse.vertical(n.alignment)
            return { d in AnyView(HStack(alignment: a, spacing: spacing) { build(kids, d) }) }
        case .zstack:
            let a = FeedParse.alignment(n.alignment)
            return { d in AnyView(ZStack(alignment: a) { build(kids, d) }) }
        case .label:
            return { d in AnyView(Text(d[dataId]?.text ?? "")) }
        case .image:
            let sized = style?.width != nil || style?.height != nil
            let fill = n.styleId.flatMap { styles[$0]?.contentMode } == "fill"
            return { d in AnyView(image(d[dataId], sized: sized, fill: fill)) }
        case .spacer:
            return { _ in AnyView(Spacer(minLength: 0)) }
        case .divider:
            return { _ in AnyView(Divider()) }
        case .progress:
            return { d in AnyView(ProgressView(value: min(max(d[dataId]?.value ?? 0, 0), 1))) }
        case .carousel:
            guard let template else { return { _ in AnyView(EmptyView()) } }
            let inset = CGFloat(n.inset ?? 0)
            return { d in
                let entries = d[dataId]?.items ?? []
                return AnyView(
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: spacing ?? 12) {
                            ForEach(entries.indices, id: \.self) { template(entries[$0]) }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, inset, for: .scrollContent)
                )
            }
        case .grid:
            guard let template else { return { _ in AnyView(EmptyView()) } }
            let s = spacing ?? 12
            let columns = Array(repeating: GridItem(.flexible(), spacing: s, alignment: .top),
                                count: max(n.columns ?? 2, 1))
            return { d in
                let entries = d[dataId]?.items ?? []
                return AnyView(
                    LazyVGrid(columns: columns, alignment: .leading, spacing: s) {
                        ForEach(entries.indices, id: \.self) { template(entries[$0]) }
                    }
                )
            }
        case .vlist:
            guard let template else { return { _ in AnyView(EmptyView()) } }
            return { d in
                let entries = d[dataId]?.items ?? []
                return AnyView(
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: spacing ?? 0) {
                            ForEach(entries.indices, id: \.self) { template(entries[$0]) }
                        }
                    }
                )
            }
        }
    }

    private static func build(_ kids: [FeedBuilder], _ d: [String: FeedData]) -> some View {
        ForEach(kids.indices, id: \.self) { kids[$0](d) }
    }

    @ViewBuilder
    static func image(_ v: FeedData?, sized: Bool, fill: Bool) -> some View {
        if let symbol = v?.symbol {
            if sized {
                Image(systemName: symbol).resizable().aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                Image(systemName: symbol)
            }
        } else if let urlString = v?.url, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let img = phase.image { img.resizable().aspectRatio(contentMode: fill ? .fill : .fit) }
                else { Color.gray.opacity(0.15) }
            }
        }
    }
}

// One body per feed row; equatable on item id so List never re-evaluates a
// row whose content hasn't changed.
struct CompiledFeedRow: View, Equatable {
    let item: FeedItem
    let build: FeedBuilder

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.item.id == rhs.item.id }

    var body: some View {
        let _ = BodyEvalCounter.shared.compiledTick()
        build(item.data)
    }
}

struct CompiledFeedListView: View {
    let feed: CompiledFeed

    var body: some View {
        List(feed.items) { item in
            if let build = feed.layouts[item.layoutId] {
                CompiledFeedRow(item: item, build: build)
                    .equatable()
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}
