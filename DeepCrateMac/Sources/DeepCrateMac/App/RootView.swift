import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case library = "Library"
    case plan = "Build Set"
    case sets = "Sets"
    case gaps = "Gaps"
    case discover = "Discover"
    case export = "Export"

    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem? = .library
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        GeometryReader { proxy in
            NavigationSplitView(columnVisibility: $splitViewVisibility) {
                ZStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.20), Color.orange.opacity(0.10), Color.teal.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DeepCrate")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Build playable crates from your own library.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.orange.opacity(0.14), Color.teal.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )

                        List(SidebarItem.allCases, selection: $selection) { item in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: item))
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 24)
                                Text(item.rawValue)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .allowsTightening(true)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .tag(item)
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.sidebar)
                        .background(Color.clear)
                    }
                    .padding(14)
                }
                .navigationTitle("DeepCrate")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
            } detail: {
                ZStack {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.08), Color.white.opacity(0.06), Color.teal.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 540, height: 540)
                        .blur(radius: 78)
                        .offset(x: -320, y: -260)

                    Circle()
                        .fill(Color.teal.opacity(0.14))
                        .frame(width: 640, height: 640)
                        .blur(radius: 92)
                        .offset(x: 340, y: 250)

                    RoundedRectangle(cornerRadius: 280, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 760, height: 420)
                        .blur(radius: 40)
                        .offset(x: 180, y: -220)

                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 16) {
                            Spacer(minLength: 0)

                            contentStatusBadge(for: proxy.size.width)
                        }
                        .frame(maxWidth: .infinity)

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
                        .groupBoxStyle(LiquidGroupBoxStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: 1380, maxHeight: .infinity, alignment: .topLeading)
                    .liquidPane(cornerRadius: LiquidMetrics.paneRadius)
                    .padding(detailPanePadding(for: proxy.size.width))
                }
            }
            .navigationSplitViewStyle(.balanced)
            .background(WindowAppearanceConfigurator(minContentSize: CGSize(width: 820, height: 600)))
            .onAppear {
                applyResponsiveChrome(for: proxy.size.width)
            }
            .onChange(of: proxy.size) { _, newSize in
                applyResponsiveChrome(for: newSize.width)
            }
        }
        .controlSize(.large)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar")
            }
        }
    }
}

private extension RootView {
    func applyResponsiveChrome(for width: CGFloat) {
        let desiredVisibility: NavigationSplitViewVisibility = width < 1020 ? .detailOnly : .all
        if splitViewVisibility != desiredVisibility {
            splitViewVisibility = desiredVisibility
        }
    }

    func detailPanePadding(for width: CGFloat) -> CGFloat {
        if width < 980 { return 14 }
        if width < 1180 { return 18 }
        return 24
    }

    func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }

    func icon(for item: SidebarItem) -> String {
        switch item {
        case .library: return "music.note.list"
        case .plan: return "wand.and.stars"
        case .sets: return "list.number"
        case .gaps: return "link.badge.plus"
        case .discover: return "magnifyingglass"
        case .export: return "square.and.arrow.up"
        }
    }

    @ViewBuilder
    func contentStatusBadge(for width: CGFloat) -> some View {
        if width < 1180 {
            CompactToolbarStatusBadge(
                taskLabel: appState.activeTaskLabel,
                statusText: appState.statusMessage,
                isWorking: appState.isWorking,
                progressCurrent: appState.progressCurrent,
                progressTotal: appState.progressTotal,
                indeterminate: appState.progressIndeterminate
            )
        } else {
            LiquidStatusBadge(
                text: appState.statusMessage,
                taskLabel: appState.activeTaskLabel,
                isWorking: appState.isWorking,
                progressCurrent: appState.progressCurrent,
                progressTotal: appState.progressTotal,
                indeterminate: appState.progressIndeterminate,
                updatedAt: appState.statusUpdatedAt
            )
        }
    }
}

private struct CompactToolbarStatusBadge: View {
    let taskLabel: String
    let statusText: String
    let isWorking: Bool
    let progressCurrent: Int
    let progressTotal: Int
    let indeterminate: Bool

    private var iconName: String {
        isWorking ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill"
    }

    private var tone: Color {
        isWorking ? .blue : .green
    }

    private var progressLabel: String {
        guard isWorking else { return "Ready" }
        if indeterminate || progressTotal <= 0 { return "Working" }
        return "\(min(progressCurrent, progressTotal))/\(progressTotal)"
    }

    private var detailLabel: String {
        let trimmed = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isWorking {
            return progressLabel
        }
        return trimmed.isEmpty || trimmed == "Ready" ? "Idle" : trimmed
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
                .symbolEffect(.pulse.byLayer, isActive: isWorking)

            Text(isWorking ? taskLabel : "Ready")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Divider()
                .frame(height: 12)

            Text(detailLabel)
                .font(isWorking ? .caption.monospacedDigit() : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(ToolbarStatusPillBackground())
        .help(statusText)
    }
}
