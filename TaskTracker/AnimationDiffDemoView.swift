import SwiftUI

/// Side-by-side proof that type erasure defeats SwiftUI's automatic diffing.
/// Left card keeps one concrete view type across the state change, so SwiftUI
/// diffs it and animates height/opacity/color smoothly. Right card rebuilds a
/// different concrete view per state and boxes it in `AnyView`, so SwiftUI sees
/// a brand-new subtree each time and the change pops instead of animating.
struct AnimationDiffDemoView: View {
    @State private var items: [DiffDemoItem] = DiffDemoItem.mockData

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tap a row to expand it. **some View** interpolates smoothly; **AnyView** snaps because its concrete type changes every update.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach($items) { $item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("some View").font(.caption.bold()).foregroundStyle(.blue)
                            TypedDiffCard(item: item)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AnyView").font(.caption.bold()).foregroundStyle(.red)
                            ErasedDiffCard(item: item)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            item.isExpanded.toggle()
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Animation Diff")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Toggle All") {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            for i in items.indices { items[i].isExpanded.toggle() }
                        }
                    }
                }
            }
        }
    }
}

struct DiffDemoItem: Identifiable {
    let id: Int
    var isExpanded = false
    var tint: Color

    static let mockData: [DiffDemoItem] = {
        let tints: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo]
        return (0..<6).map { i in DiffDemoItem(id: i, tint: tints[i % tints.count]) }
    }()
}

/// Same concrete type in both states — SwiftUI diffs it and animates the frame/color change.
struct TypedDiffCard: View, Equatable {
    let item: DiffDemoItem

    static func == (lhs: TypedDiffCard, rhs: TypedDiffCard) -> Bool {
        lhs.item.id == rhs.item.id && lhs.item.isExpanded == rhs.item.isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Card \(item.id)")
                .font(.subheadline.weight(.semibold))
            if item.isExpanded {
                Text("Expanded in the SAME view hierarchy — SwiftUI just animates height, opacity, and color.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: item.isExpanded ? 110 : 48)
        .background(item.tint.opacity(item.isExpanded ? 0.28 : 0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Builds a DIFFERENT concrete view per state and erases it with `AnyView` — SwiftUI
/// can't interpolate between two unrelated types, so the change pops instead of animating.
struct ErasedDiffCard: View {
    let item: DiffDemoItem

    var body: some View {
        if item.isExpanded {
            AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    Text("Card \(item.id)")
                        .font(.subheadline.weight(.semibold))
                    Text("Expanded via a DIFFERENT view instance behind AnyView — SwiftUI can't interpolate, it just swaps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 110)
                .background(item.tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            )
        } else {
            AnyView(
                HStack {
                    Text("Card \(item.id)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 48)
                .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            )
        }
    }
}

#Preview {
    AnimationDiffDemoView()
}
