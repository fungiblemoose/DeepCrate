import AppKit
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var query: String = ""
    @State private var bpmRange: String = ""
    @State private var key: String = ""
    @State private var energyRange: String = ""
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library")
                .font(.largeTitle.bold())

            GroupBox("Scan") {
                HStack {
                    Button("Choose Folder") {
                        pickFolder()
                    }
                    Button("Scan") {
                        Task { await scan() }
                    }
                    .disabled(isBusy || appState.scannedFolder.isEmpty)
                    Text(appState.scannedFolder.isEmpty ? "No folder selected" : appState.scannedFolder)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            GroupBox("Search") {
                HStack {
                    TextField("Query", text: $query)
                    TextField("BPM Range", text: $bpmRange)
                    TextField("Key", text: $key)
                    TextField("Energy Range", text: $energyRange)
                    Button("Search") { Task { await loadTracks() } }
                        .disabled(isBusy)
                }
                .textFieldStyle(.roundedBorder)
            }

            Table(appState.libraryTracks) {
                TableColumn("Artist", value: \.artist)
                TableColumn("Title", value: \.title)
                TableColumn("BPM") { track in Text("\(Int(track.bpm))") }
                TableColumn("Key", value: \.key)
                TableColumn("Energy") { track in Text(String(format: "%.2f", track.energy)) }
            }
            .frame(minHeight: 420)
        }
        .task {
            await loadTracks()
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            appState.scannedFolder = url.path
        }
    }

    private func scan() async {
        isBusy = true
        defer { isBusy = false }
        let folder = appState.scannedFolder

        do {
            let status = try await Task.detached {
                try BackendClient().scan(directory: folder)
            }.value
            appState.statusMessage = status
            await loadTracks()
        } catch {
            appState.statusMessage = "Scan failed: \(error.localizedDescription)"
        }
    }

    private func loadTracks() async {
        isBusy = true
        defer { isBusy = false }
        let localQuery = query
        let localBPM = bpmRange
        let localKey = key
        let localEnergy = energyRange

        do {
            let tracks = try await Task.detached {
                try BackendClient().tracks(
                    query: localQuery,
                    bpm: localBPM,
                    key: localKey,
                    energy: localEnergy
                )
            }.value
            appState.libraryTracks = tracks
            appState.statusMessage = "Loaded \(tracks.count) tracks"
        } catch {
            appState.statusMessage = "Track load failed: \(error.localizedDescription)"
        }
    }
}
