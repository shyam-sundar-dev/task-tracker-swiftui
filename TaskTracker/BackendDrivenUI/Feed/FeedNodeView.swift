import SwiftUI

// Recursive renderer: one body per layout node. `data` is the scope dataIds
// resolve against — the item's data map, or a single entry for collection templates.
struct FeedNodeView: View {
    let node: FeedNode
    let data: [String: FeedData]
    let styles: [String: FeedStyle]

    private var style: FeedStyle? { node.styleId.flatMap { styles[$0] } }
    private var value: FeedData? { node.dataId.flatMap { data[$0] } }

    var body: some View {
        BodyEvalCounter.shared.nodeTick()
        return content.feedStyle(style)
    }

    @ViewBuilder
    private var content: some View {
        let spacing = node.spacing.map { CGFloat($0) }
        switch node.type {
        case .vstack:
            VStack(alignment: FeedParse.horizontal(node.alignment ?? "leading"), spacing: spacing) { children }
        case .hstack:
            HStack(alignment: FeedParse.vertical(node.alignment), spacing: spacing) { children }
        case .zstack:
            ZStack(alignment: FeedParse.alignment(node.alignment)) { children }
        case .label:
            Text(value?.text ?? "")
        case .image:
            image
        case .spacer:
            Spacer(minLength: 0)
        case .divider:
            Divider()
        case .progress:
            ProgressView(value: min(max(value?.value ?? 0, 0), 1))
        case .carousel:
            carousel(spacing: spacing ?? 12)
        case .grid:
            grid(spacing: spacing ?? 12)
        case .vlist:
            vlist(spacing: spacing ?? 0)
        }
    }

    private var children: some View {
        ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
            FeedNodeView(node: child, data: data, styles: styles)
        }
    }

    @ViewBuilder
    private var image: some View {
        let sized = style?.width != nil || style?.height != nil
        let fill = style?.contentMode == "fill"
        if let urlString = value?.url, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: fill ? .fill : .fit)
                } else {
                    Color.gray.opacity(0.15)
                }
            }
        } else if let symbol = value?.symbol {
            if sized {
                Image(systemName: symbol).resizable().aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                Image(systemName: symbol)
            }
        }
    }

    // MARK: Collections — template rendered once per data[dataId].items entry

    private var entries: [[String: FeedData]] { value?.items ?? [] }

    @ViewBuilder
    private func carousel(spacing: CGFloat) -> some View {
        if let template = node.template {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: spacing) {
                    ForEach(entries.indices, id: \.self) { i in
                        FeedNodeView(node: template, data: entries[i], styles: styles)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, CGFloat(node.inset ?? 0), for: .scrollContent)
        }
    }

    @ViewBuilder
    private func vlist(spacing: CGFloat) -> some View {
        if let template = node.template {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    ForEach(entries.indices, id: \.self) { i in
                        FeedNodeView(node: template, data: entries[i], styles: styles)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func grid(spacing: CGFloat) -> some View {
        if let template = node.template {
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
                                count: max(node.columns ?? 2, 1))
            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                ForEach(entries.indices, id: \.self) { i in
                    FeedNodeView(node: template, data: entries[i], styles: styles)
                }
            }
        }
    }
}

struct FeedListView: View {
    let document: FeedDocument

    var body: some View {
        List(document.items) { item in
            if let layout = document.layouts[item.layoutId] {
                FeedNodeView(node: layout, data: item.data, styles: document.styles)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}
