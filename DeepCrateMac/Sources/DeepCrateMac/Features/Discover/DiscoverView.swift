import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var selectedSetID: Int?
    @State private var gapNumber: Int = 1
    @State private var genre: String = "drum and bass"
    @State private var limit: Int = 10
    @State private var availableGaps: [GapSuggestion] = []
    @State private var savedBridgePicks: [SavedBridgePick] = []
    @State private var isLoadingGaps = false
    @State private var isLoadingSavedPicks = false
    @State private var isDiscovering = false
    @State private var savingSuggestionURL: String?
    @State private var updatingPickID: Int?
    @State private var deletingPickID: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                controlCard

                if isLoadingGaps {
                    loadingCard
                } else if let selectedGap {
                    targetGapCard(selectedGap)
                    savedBridgePicksSection

                    if missingCredentials {
                        credentialsCard
                    } else {
                        resultsSection
                    }
                } else {
                    emptyGapCard
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .task {
            await refreshSets()
        }
        .onChange(of: selectedSetID) { _, _ in
            Task { await refreshGapTargets() }
        }
        .onChange(of: gapNumber) { _, _ in
            Task { await refreshSavedBridgePicks() }
        }
    }

    private var missingCredentials: Bool {
        settings.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || settings.spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedSetName: String? {
        appState.setSummaries.first(where: { $0.id == selectedSetID })?.name
    }

    private var selectedGapPosition: Int {
        guard !availableGaps.isEmpty else { return 1 }
        return max(1, min(gapNumber, availableGaps.count))
    }

    private var selectedGap: GapSuggestion? {
        guard !availableGaps.isEmpty else { return nil }
        return availableGaps[selectedGapPosition - 1]
    }

    private var savedBridgeURLs: Set<String> {
        Set(savedBridgePicks.map(\.url))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discover")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Work the exact handoff that feels weak, search Spotify for nearby fits, then keep a shortlist you can actually chase down later.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                DiscoverHintPill(text: missingCredentials ? "Spotify setup needed" : "Spotify ready")
                DiscoverHintPill(text: availableGaps.isEmpty ? "No active gap target" : "\(availableGaps.count) gap target\(availableGaps.count == 1 ? "" : "s")")
                if !savedBridgePicks.isEmpty {
                    DiscoverHintPill(text: "\(savedBridgePicks.count) saved pick\(savedBridgePicks.count == 1 ? "" : "s")")
                }
                if let setName = selectedSetName {
                    DiscoverHintPill(text: setName)
                }
            }
        }
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bridge Search")
                        .font(.headline)
                    Text("Pick a saved set, lock onto a weak transition, then search Spotify for bridge tracks worth keeping on your radar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isDiscovering {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                discoverFieldColumn(
                    title: "Set",
                    caption: "DeepCrate re-analyzes the selected set and keeps the active gap list in sync.",
                    content: {
                        Picker("Set", selection: $selectedSetID) {
                            Text("Select Set").tag(Optional<Int>.none)
                            ForEach(appState.setSummaries) { setPlan in
                                Text(setPlan.name).tag(Optional(setPlan.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                )

                discoverFieldColumn(
                    title: "Gap",
                    caption: availableGaps.isEmpty ? "No weak transitions found for this set yet." : "Choose the handoff you want to tighten up.",
                    content: {
                        Stepper(
                            "Gap #\(selectedGapPosition)",
                            value: $gapNumber,
                            in: 1...max(availableGaps.count, 1)
                        )
                        .disabled(availableGaps.isEmpty)
                    }
                )
            }

            HStack(alignment: .top, spacing: 12) {
                discoverFieldColumn(
                    title: "Genre Focus",
                    caption: "Broad prompts work best: `drum and bass`, `uk garage`, `afro house`, `deep dubstep`.",
                    content: {
                        TextField("drum and bass", text: $genre)
                            .textFieldStyle(.roundedBorder)
                    }
                )

                discoverFieldColumn(
                    title: "Result Count",
                    caption: "The list stays quality-first, then fills with the next best fallbacks.",
                    content: {
                        Stepper("Limit \(limit)", value: $limit, in: 5...20)
                    }
                )
            }

            HStack(spacing: 10) {
                Button {
                    Task { await discover() }
                } label: {
                    Label(isDiscovering ? "Searching..." : "Find Bridge Tracks", systemImage: "sparkle.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(missingCredentials || selectedGap == nil || isDiscovering)

                if let selectedGap {
                    Text("Target: \(Int(selectedGap.suggestedBPM.rounded())) BPM · \(selectedGap.suggestedKey) · \(String(format: "%.2f", selectedGap.suggestedEnergy)) energy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Spotify credentials are required for fresh discovery.", systemImage: "key.fill")
                .font(.headline)

            Text("Add a Spotify client ID and client secret in Settings to search new tracks. Your saved bridge picks stay here either way, so you can still manage the shortlist you already built.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SettingsLink {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .thinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text("Refreshing gap targets for the selected set...")
                .font(.headline)
            Text("Discovery works best when it starts from the exact weak transition DeepCrate wants to solve.")
                .foregroundStyle(.secondary)
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .thinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private func targetGapCard(_ gap: GapSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Gap")
                        .font(.headline)
                    Text("\(gap.fromTrack) -> \(gap.toTrack)")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("\(Int((gap.score * 100).rounded()))% match")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(discoverMatchTint(for: gap.score).opacity(0.18), in: Capsule())
                    .foregroundStyle(discoverMatchTint(for: gap.score))
            }

            HStack(spacing: 10) {
                DiscoverMetricPill(title: "Bridge BPM", value: "\(Int(gap.suggestedBPM.rounded()))")
                DiscoverMetricPill(title: "Bridge Key", value: gap.suggestedKey)
                DiscoverMetricPill(title: "Target Energy", value: String(format: "%.2f", gap.suggestedEnergy))
            }

            if !gap.weakReason.isEmpty {
                Text(gap.weakReason)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !gap.bridgeCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local Library Bridge Ideas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(gap.bridgeCandidates, id: \.self) { candidate in
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .foregroundStyle(.orange)
                            Text(candidate)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .thinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var savedBridgePicksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved Bridge Picks")
                        .font(.headline)
                    Text("Keep a working shortlist for this exact handoff. Mark the ones you really want, then flip them to acquired once they land in your library.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !savedBridgePicks.isEmpty {
                    DiscoverHintPill(text: "\(savedBridgePicks.count) tracked")
                }
            }

            if isLoadingSavedPicks {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading saved picks for this gap...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            } else if savedBridgePicks.isEmpty {
                ContentUnavailableView(
                    "No saved picks yet",
                    systemImage: "pin.slash",
                    description: Text("Run a Spotify search and save the tracks that feel worth chasing down.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(savedBridgePicks) { pick in
                        SavedBridgePickCard(
                            pick: pick,
                            isUpdatingState: updatingPickID == pick.id,
                            isDeleting: deletingPickID == pick.id,
                            onStateChange: { newState in
                                Task { await updateSavedBridgePickState(pick, state: newState) }
                            },
                            onDelete: {
                                Task { await deleteSavedBridgePick(pick) }
                            }
                        )
                    }
                }
            }
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fresh Spotify Matches")
                        .font(.headline)
                    Text("Sorted by fit for the active gap. Save the ones that actually feel usable, then let the shortlist become your working dig list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !appState.discoverResults.isEmpty {
                    DiscoverHintPill(text: "\(appState.discoverResults.count) result\(appState.discoverResults.count == 1 ? "" : "s")")
                }
            }

            if appState.discoverResults.isEmpty {
                ContentUnavailableView(
                    "No Spotify matches yet",
                    systemImage: "music.note.list",
                    description: Text("Choose a gap and run Find Bridge Tracks.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.discoverResults) { suggestion in
                        DiscoverResultCard(
                            suggestion: suggestion,
                            isSaved: savedBridgeURLs.contains(suggestion.url),
                            isSaving: savingSuggestionURL == suggestion.url,
                            onSave: {
                                Task { await saveBridgePick(suggestion) }
                            }
                        )
                    }
                }
            }
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private func discoverFieldColumn<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshSets() async {
        do {
            let sets = try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.listSets()
            }.value

            appState.setSummaries = sets
            if selectedSetID == nil {
                selectedSetID = sets.first?.id
            }
            await refreshGapTargets()
        } catch {
            appState.statusMessage = "Failed to load sets: \(error.localizedDescription)"
        }
    }

    private func refreshGapTargets() async {
        guard let selectedSetName else {
            availableGaps = []
            savedBridgePicks = []
            appState.discoverResults = []
            return
        }

        isLoadingGaps = true
        defer { isLoadingGaps = false }

        do {
            let gaps = try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.analyzeGaps(name: selectedSetName)
            }.value

            let previousGapNumber = gapNumber
            availableGaps = gaps
            if gaps.isEmpty {
                gapNumber = 1
                savedBridgePicks = []
                appState.discoverResults = []
                appState.statusMessage = "No weak transitions found for \(selectedSetName)"
            } else {
                gapNumber = min(max(gapNumber, 1), gaps.count)
                appState.discoverResults = []
                if previousGapNumber == gapNumber {
                    await refreshSavedBridgePicks()
                }
                appState.statusMessage = "Loaded \(gaps.count) gap target\(gaps.count == 1 ? "" : "s") for \(selectedSetName)"
            }
        } catch {
            availableGaps = []
            savedBridgePicks = []
            appState.discoverResults = []
            appState.statusMessage = "Gap refresh failed: \(error.localizedDescription)"
        }
    }

    private func refreshSavedBridgePicks() async {
        guard let selectedSetID, let selectedGap else {
            savedBridgePicks = []
            return
        }

        let requestedSetID = selectedSetID
        let requestedFromTrack = selectedGap.fromTrack
        let requestedToTrack = selectedGap.toTrack

        isLoadingSavedPicks = true
        defer { isLoadingSavedPicks = false }

        do {
            let picks = try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.savedBridgePicks(
                    setID: requestedSetID,
                    fromTrack: requestedFromTrack,
                    toTrack: requestedToTrack
                )
            }.value

            guard self.selectedSetID == requestedSetID,
                  self.selectedGap?.fromTrack == requestedFromTrack,
                  self.selectedGap?.toTrack == requestedToTrack else {
                return
            }
            savedBridgePicks = picks
        } catch {
            savedBridgePicks = []
            appState.statusMessage = "Failed to load saved bridge picks: \(error.localizedDescription)"
        }
    }

    private func discover() async {
        guard let selectedGap else {
            appState.statusMessage = "No weak transition available to search against."
            return
        }

        isDiscovering = true
        appState.beginTask("Spotify Discovery", indeterminate: true)
        defer {
            isDiscovering = false
            appState.completeTask(label: "Ready")
        }

        do {
            let localGenre = genre
            let localLimit = limit
            let results = try await Task.detached(priority: .userInitiated) {
                try await SpotifyDiscoveryService.shared.discover(
                    for: selectedGap,
                    genre: localGenre,
                    limit: localLimit
                )
            }.value

            appState.discoverResults = results
            appState.statusMessage = results.isEmpty
                ? "Spotify returned no close matches for this gap."
                : "Found \(results.count) Spotify suggestion\(results.count == 1 ? "" : "s")"
        } catch {
            appState.statusMessage = "Discover failed: \(error.localizedDescription)"
        }
    }

    private func saveBridgePick(_ suggestion: DiscoverSuggestion) async {
        guard let selectedSetID, let selectedGap else {
            appState.statusMessage = "Pick a set and active gap before saving bridge tracks."
            return
        }

        let gapPosition = selectedGapPosition
        savingSuggestionURL = suggestion.url
        defer { savingSuggestionURL = nil }

        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.saveBridgePick(
                    setID: selectedSetID,
                    gapPosition: gapPosition,
                    gap: selectedGap,
                    suggestion: suggestion
                )
            }.value

            await refreshSavedBridgePicks()
            appState.statusMessage = "Saved \(suggestion.artist) - \(suggestion.title) to bridge picks."
        } catch {
            appState.statusMessage = "Failed to save bridge pick: \(error.localizedDescription)"
        }
    }

    private func updateSavedBridgePickState(_ pick: SavedBridgePick, state: SavedBridgePickState) async {
        guard pick.state != state else { return }

        updatingPickID = pick.id
        defer { updatingPickID = nil }

        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.updateSavedBridgePickState(pickID: pick.id, state: state)
            }.value
            await refreshSavedBridgePicks()
            appState.statusMessage = "\(state.label) pick: \(pick.artist) - \(pick.title)"
        } catch {
            appState.statusMessage = "Failed to update saved pick: \(error.localizedDescription)"
        }
    }

    private func deleteSavedBridgePick(_ pick: SavedBridgePick) async {
        deletingPickID = pick.id
        defer { deletingPickID = nil }

        do {
            try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.deleteSavedBridgePick(pickID: pick.id)
            }.value
            await refreshSavedBridgePicks()
            appState.statusMessage = "Removed \(pick.artist) - \(pick.title) from bridge picks."
        } catch {
            appState.statusMessage = "Failed to delete saved pick: \(error.localizedDescription)"
        }
    }

    private var emptyGapCard: some View {
        ContentUnavailableView(
            "No weak transitions for this set",
            systemImage: "checkmark.seal",
            description: Text("Discovery needs a gap target. Pick another set or run Build Set/Gaps on something rougher.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .thinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }
}

private struct DiscoverMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DiscoverHintPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct DiscoverArtworkView: View {
    let imageURL: String

    var body: some View {
        let placeholder = RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.45),
                        Color.teal.opacity(0.35),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            )

        if let url = URL(string: imageURL), !imageURL.isEmpty {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            placeholder
                .frame(width: 88, height: 88)
        }
    }
}

private struct DiscoverResultCard: View {
    let suggestion: DiscoverSuggestion
    let isSaved: Bool
    let isSaving: Bool
    let onSave: () -> Void

    private var spotifyURL: URL? {
        URL(string: suggestion.url)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            DiscoverArtworkView(imageURL: suggestion.artworkURL)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(suggestion.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if !suggestion.album.isEmpty {
                            Text(suggestion.album)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("\(Int((suggestion.matchScore * 100).rounded()))% fit")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(discoverMatchTint(for: suggestion.matchScore).opacity(0.16), in: Capsule())
                        .foregroundStyle(discoverMatchTint(for: suggestion.matchScore))
                }

                HStack(spacing: 10) {
                    DiscoverMetricPill(title: "BPM", value: String(format: "%.1f", suggestion.bpm))
                    if !suggestion.camelotKey.isEmpty {
                        DiscoverMetricPill(title: "Key", value: suggestion.camelotKey)
                    }
                    DiscoverMetricPill(title: "Energy", value: String(format: "%.2f", suggestion.energy))
                    DiscoverMetricPill(title: "Tempo Δ", value: String(format: "%.1f", suggestion.tempoDelta))
                    DiscoverMetricPill(title: "Energy Δ", value: String(format: "%.2f", suggestion.energyDelta))
                }

                HStack(spacing: 10) {
                    Button {
                        onSave()
                    } label: {
                        if isSaving {
                            Label("Saving...", systemImage: "arrow.triangle.2.circlepath")
                        } else if isSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                        } else {
                            Label("Save Pick", systemImage: "pin.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isSaved ? .gray : .accentColor)
                    .disabled(isSaved || isSaving)

                    if let spotifyURL {
                        Link(destination: spotifyURL) {
                            Label("Open in Spotify", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SavedBridgePickCard: View {
    let pick: SavedBridgePick
    let isUpdatingState: Bool
    let isDeleting: Bool
    let onStateChange: (SavedBridgePickState) -> Void
    let onDelete: () -> Void

    private var spotifyURL: URL? {
        URL(string: pick.url)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            DiscoverArtworkView(imageURL: pick.artworkURL)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pick.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(pick.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if !pick.album.isEmpty {
                            Text(pick.album)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        DiscoverHintPill(text: "Gap #\(pick.gapPosition)")
                        SavedBridgeStateBadge(state: pick.state)
                    }
                }

                HStack(spacing: 10) {
                    DiscoverMetricPill(title: "Match", value: "\(Int((pick.matchScore * 100).rounded()))%")
                    DiscoverMetricPill(title: "BPM", value: String(format: "%.1f", pick.bpm))
                    DiscoverMetricPill(title: "Energy", value: String(format: "%.2f", pick.energy))
                    DiscoverMetricPill(title: "Tempo Δ", value: String(format: "%.1f", pick.tempoDelta))
                }

                HStack(spacing: 10) {
                    Menu {
                        ForEach(SavedBridgePickState.allCases) { state in
                            Button {
                                onStateChange(state)
                            } label: {
                                Label(state.label, systemImage: stateSymbol(for: state))
                            }
                        }
                    } label: {
                        if isUpdatingState {
                            Label("Updating...", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Set Status", systemImage: "tag")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUpdatingState || isDeleting)

                    if let spotifyURL {
                        Link(destination: spotifyURL) {
                            Label("Open in Spotify", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        if isDeleting {
                            Label("Removing...", systemImage: "trash")
                        } else {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting || isUpdatingState)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func stateSymbol(for state: SavedBridgePickState) -> String {
        switch state {
        case .saved:
            return "pin.fill"
        case .priority:
            return "exclamationmark.circle.fill"
        case .acquired:
            return "checkmark.circle.fill"
        }
    }
}

private struct SavedBridgeStateBadge: View {
    let state: SavedBridgePickState

    var body: some View {
        Text(state.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(savedBridgeStateTint(for: state).opacity(0.16), in: Capsule())
            .foregroundStyle(savedBridgeStateTint(for: state))
    }
}

private func discoverMatchTint(for score: Double) -> Color {
    if score < 0.25 {
        return .red
    }
    if score < 0.35 {
        return .orange
    }
    if score < 0.45 {
        return .yellow
    }
    return .green
}

private func savedBridgeStateTint(for state: SavedBridgePickState) -> Color {
    switch state {
    case .saved:
        return .blue
    case .priority:
        return .orange
    case .acquired:
        return .green
    }
}
