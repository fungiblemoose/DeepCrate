import SwiftUI

struct SetsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSetID: Int?
    @State private var rows: [SetTrackRow] = []

    private var selectedSet: SetSummary? {
        appState.setSummaries.first(where: { $0.id == selectedSetID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sets")
                .font(.largeTitle.bold())

            GroupBox("Set Selection") {
                HStack {
                    Picker("Set", selection: $selectedSetID) {
                        Text("Select Set").tag(Optional<Int>.none)
                        ForEach(appState.setSummaries) { setPlan in
                            Text(setPlan.name).tag(Optional(setPlan.id))
                        }
                    }
                    .frame(maxWidth: 360)
                    .onChange(of: selectedSetID) { _, _ in
                        Task { await loadSelectedSetRows() }
                    }

                    Button("Refresh Sets") {
                        Task { await refreshSets() }
                    }
                }
            }

            if let setPlan = selectedSet {
                Text(setPlan.description)
                    .foregroundStyle(.secondary)
                Table(rows) {
                    TableColumn("#") { row in Text("\(row.position)") }
                    TableColumn("Artist", value: \.artist)
                    TableColumn("Title", value: \.title)
                    TableColumn("BPM") { row in Text("\(Int(row.bpm))") }
                    TableColumn("Key", value: \.key)
                    TableColumn("Energy") { row in Text(String(format: "%.2f", row.energy)) }
                    TableColumn("Transition", value: \.transition)
                }
                .frame(minHeight: 420)
            } else {
                ContentUnavailableView("No set selected", systemImage: "list.number")
            }
        }
        .task {
            await refreshSets()
        }
    }

    private func refreshSets() async {
        do {
            let sets = try await Task.detached {
                try BackendClient().sets()
            }.value
            appState.setSummaries = sets
            if selectedSetID == nil {
                selectedSetID = sets.first?.id
            }
            await loadSelectedSetRows()
        } catch {
            appState.statusMessage = "Failed to load sets: \(error.localizedDescription)"
        }
    }

    private func loadSelectedSetRows() async {
        guard let selectedSet else { return }
        let name = selectedSet.name
        do {
            let loadedRows = try await Task.detached {
                try BackendClient().setTracks(name: name)
            }.value
            rows = loadedRows
        } catch {
            appState.statusMessage = "Failed to load set tracks: \(error.localizedDescription)"
        }
    }
}
