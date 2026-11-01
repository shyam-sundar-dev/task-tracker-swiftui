import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case performanceTesting = "Performance Testing"
    case animationDiff      = "Animation Diff"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .performanceTesting: return "speedometer"
        case .animationDiff:      return "wand.and.stars"
        }
    }
}

/// Sidebar root: one section per demo area. New demos get a new `SidebarItem` case.
struct AppRootView: View {
    @State private var selection: SidebarItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationTitle("Task Tracker")
        } detail: {
            switch selection {
            case .performanceTesting:
                PerformanceTestingView()
            case .animationDiff:
                AnimationDiffDemoView()
            case nil:
                ContentUnavailableView(
                    "Pick a demo",
                    systemImage: "sidebar.left",
                    description: Text("Choose Performance Testing or Animation Diff from the sidebar.")
                )
            }
        }
    }
}

#Preview {
    AppRootView()
}
