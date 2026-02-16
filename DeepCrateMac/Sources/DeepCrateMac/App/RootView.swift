import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case library = "Library"
    case plan = "Plan Set"
    case sets = "Sets"
    case gaps = "Gaps"
    case discover = "Discover"
    case export = "Export"

    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem? = .library

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: icon(for: item))
                    .tag(item)
            }
            .navigationTitle("DeepCrate")
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection ?? .library {
                case .library:
                    LibraryView()
                case .plan:
                    PlanView()
                case .sets:
                    SetsView()
                case .gaps:
                    GapsView()
                case .discover:
                    DiscoverView()
                case .export:
                    ExportView()
                }
            }
            .padding(20)
            .background(.regularMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func icon(for item: SidebarItem) -> String {
        switch item {
        case .library: return "music.note.list"
        case .plan: return "wand.and.stars"
        case .sets: return "list.number"
        case .gaps: return "link.badge.plus"
        case .discover: return "magnifyingglass"
        case .export: return "square.and.arrow.up"
        }
    }
}
