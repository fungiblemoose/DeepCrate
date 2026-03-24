import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var selectedSetID: Int?
    @State private var gapNumber: Int = 1
    @State private var genre: String = "drum and bass"
    @State private var limit: Int = 10
    @State private var availableGaps: [GapSuggestion] = []
    @State private var isLoadingGaps = false
    @State private var isDiscovering = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                controlCard

                if missingCredentials {
                    credentialsCard
                } else if isLoadingGaps {
                    loadingCard
                } else if let selectedGap {
                    targetGapCard(selectedGap)
                    resultsSection
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
    }

    private var missingCredentials: Bool {
        settings.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || settings.spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedSetName: String? {
        appState.setSummaries.first(where: { $0.id == selectedSetID })?.name
    }

    private var selectedGap: GapSuggestion? {
        guard !availableGaps.isEmpty else { return nil }
        let index = max(0, min(gapNumber - 1, availableGaps.count - 1))
        return availableGaps[index]
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discover")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Pull Spotify ideas for the exact weak handoff you want to fix. DeepCrate reads the gap target, then finds tracks that land near the right tempo and energy.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                DiscoverHintPill(text: missingCredentials ? "Spotify setup needed" : "Spotify ready")
                DiscoverHintPill(text: availableGaps.isEmpty ? "No active gap target" : "\(availableGaps.count) gap target\(availableGaps.count == 1 ? "" : "s")")
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
                    Text("Lookup")
                        .font(.headline)
                    Text("Choose a saved set, let DeepCrate refresh its weak transitions, then search Spotify for a bridge track.")
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
                    caption: "Discovery auto-loads the set's current weak transitions.",
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
                    caption: availableGaps.isEmpty ? "No weak transitions found for this set yet." : "Pick the handoff you want to repair.",
                    content: {
                        Stepper(
                            "Gap #\(min(gapNumber, max(availableGaps.count, 1)))",
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
                    caption: "Use a broad phrase like `drum and bass`, `uk garage`, or `afro house`.",
                    content: {
                        TextField("drum and bass", text: $genre)
                            .textFieldStyle(.roundedBorder)
                    }
                )

                discoverFieldColumn(
                    title: "Result Count",
                    caption: "DeepCrate prefers close fits first, then fills with the next best options.",
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

                if !missingCredentials, let selectedGap {
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
            Label("Spotify credentials are required for discovery.", systemImage: "key.fill")
                .font(.headline)

            Text("Add a Spotify client ID and client secret in Settings. This app uses the same client-credentials flow the old Python bridge used, but now the request stays inside the Swift app.")
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
            Text("Discover works best when it starts from the exact weak transition DeepCrate wants to solve.")
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
                    .background(matchTint(for: gap.score).opacity(0.18), in: Capsule())
                    .foregroundStyle(matchTint(for: gap.score))
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
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .thinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spotify Matches")
                        .font(.headline)
                    Text("Sorted by fit for the selected gap. Strong matches stay close on tempo and energy; weaker fallbacks still show up if Spotify does not have many clean options.")
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
                        DiscoverResultCard(suggestion: suggestion)
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
            appState.discoverResults = []
            return
        }

        isLoadingGaps = true
        defer { isLoadingGaps = false }

        do {
            let gaps = try await Task.detached(priority: .userInitiated) {
                try LocalDatabase.shared.analyzeGaps(name: selectedSetName)
            }.value

            availableGaps = gaps
            if gaps.isEmpty {
                gapNumber = 1
                appState.discoverResults = []
                appState.statusMessage = "No weak transitions found for \(selectedSetName)"
            } else {
                gapNumber = min(max(gapNumber, 1), gaps.count)
                appState.discoverResults = []
                appState.statusMessage = "Loaded \(gaps.count) gap target\(gaps.count == 1 ? "" : "s") for \(selectedSetName)"
            }
        } catch {
            availableGaps = []
            appState.discoverResults = []
            appState.statusMessage = "Gap refresh failed: \(error.localizedDescription)"
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

    private func matchTint(for score: Double) -> Color {
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

private struct DiscoverResultCard: View {
    let suggestion: DiscoverSuggestion

    private var spotifyURL: URL? {
        URL(string: suggestion.url)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            artwork

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
                        .background(Color.orange.opacity(0.16), in: Capsule())
                }

                HStack(spacing: 10) {
                    DiscoverMetricPill(title: "BPM", value: String(format: "%.1f", suggestion.bpm))
                    DiscoverMetricPill(title: "Energy", value: String(format: "%.2f", suggestion.energy))
                    DiscoverMetricPill(title: "Tempo Δ", value: String(format: "%.1f", suggestion.tempoDelta))
                    DiscoverMetricPill(title: "Energy Δ", value: String(format: "%.2f", suggestion.energyDelta))
                }

                if let spotifyURL {
                    Link(destination: spotifyURL) {
                        Label("Open in Spotify", systemImage: "arrow.up.forward.square")
                    }
                    .buttonStyle(.bordered)
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

    @ViewBuilder
    private var artwork: some View {
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

        if let url = URL(string: suggestion.artworkURL), !suggestion.artworkURL.isEmpty {
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
