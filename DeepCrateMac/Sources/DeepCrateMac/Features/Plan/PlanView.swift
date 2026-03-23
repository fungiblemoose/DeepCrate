import SwiftUI

struct PlanView: View {
    private struct PromptPreset: Identifiable {
        let id = UUID()
        let title: String
        let caption: String
        let setName: String
        let duration: Int
        let prompt: String
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var name: String = ""
    @State private var duration: Int = 60
    @State private var description: String = ""
    @State private var isPlanning = false
    @State private var inlineMessage: String = ""
    @State private var inlineMessageIsError = false

    private let presets: [PromptPreset] = [
        PromptPreset(
            title: "Liquid Warmup",
            caption: "Mellow open, proper lift, clean glide-out.",
            setName: "Liquid Warmup",
            duration: 60,
            prompt: "60 minute liquid dnb journey, start mellow, build to a peak around minute 40, then cool down"
        ),
        PromptPreset(
            title: "Warehouse Pressure",
            caption: "No wasted motion. Dense, driving, late-night.",
            setName: "Warehouse Pressure",
            duration: 75,
            prompt: "75 minute hard techno set, relentless pressure, sharp transitions, hold intensity without burning out too early"
        ),
        PromptPreset(
            title: "Sunset Drift",
            caption: "Warm percussion, emotional finish, no harsh turns.",
            setName: "Sunset Drift",
            duration: 90,
            prompt: "90 minute afro house into melodic house set for sunset, organic groove opening, steady lift, warm emotional finish"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                modeSection
                factStrip
                composerSection

                if !inlineMessage.isEmpty {
                    messageBanner
                }
            }
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .task {
            await refreshSets()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Build a Set That Feels Intentional")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .lineLimit(2)

                Text("Describe the room, the mood, and the energy arc. DeepCrate turns your local library into something playable.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)

            LiquidStatusBadge(
                text: plannerBadgeText,
                taskLabel: "Planner",
                isWorking: isPlanning,
                progressCurrent: 0,
                progressTotal: 0,
                indeterminate: true,
                updatedAt: appState.statusUpdatedAt
            )
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Planning Engine")
                    .font(.headline)
                Spacer()
                Text(settings.plannerMode == .localServer ? "Recommended for stronger local planning" : "Fastest built-in path")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    plannerModeCard(
                        mode: .localServer,
                        icon: "cpu.fill",
                        accent: [Color.orange.opacity(0.65), Color.red.opacity(0.35)],
                        title: "Local Model Server",
                        subtitle: "Best quality if you are running Qwen or another local instruct model."
                    )
                    plannerModeCard(
                        mode: .localApple,
                        icon: "apple.logo",
                        accent: [Color.teal.opacity(0.6), Color.cyan.opacity(0.34)],
                        title: "Apple On-Device",
                        subtitle: "Zero setup fallback using the built-in Apple model when available."
                    )
                }

                VStack(spacing: 12) {
                    plannerModeCard(
                        mode: .localServer,
                        icon: "cpu.fill",
                        accent: [Color.orange.opacity(0.65), Color.red.opacity(0.35)],
                        title: "Local Model Server",
                        subtitle: "Best quality if you are running Qwen or another local instruct model."
                    )
                    plannerModeCard(
                        mode: .localApple,
                        icon: "apple.logo",
                        accent: [Color.teal.opacity(0.6), Color.cyan.opacity(0.34)],
                        title: "Apple On-Device",
                        subtitle: "Zero setup fallback using the built-in Apple model when available."
                    )
                }
            }

            if settings.plannerMode == .localServer {
                plannerDetailPanel(
                    title: settings.localModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Choose a model in Settings" : settings.localModelName,
                    subtitle: settings.localModelEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No endpoint configured" : settings.localModelEndpoint,
                    tone: .orange,
                    symbol: "network.badge.shield.half.filled",
                    body: "DeepCrate sends a ranked catalog of local tracks to your local model server and only accepts ordered track IDs back."
                )
            } else {
                plannerDetailPanel(
                    title: "Apple Foundation Model",
                    subtitle: "On-device, private, and built into the Mac when available",
                    tone: .teal,
                    symbol: "sparkles.rectangle.stack",
                    body: "This mode is the built-in fallback. It keeps planning inside the app and works without running another service."
                )
            }
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 16, shadowOpacity: 0.05)
    }

    private var factStrip: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            PlanFactCard(title: "Selected Engine", value: settings.plannerMode.rawValue, detail: settings.plannerMode == .localServer ? "Local endpoint + model" : "Built-in fallback")
            PlanFactCard(title: "Target Length", value: "\(duration) min", detail: "\(targetTrackCount) planned tracks")
            PlanFactCard(title: "Library Ready", value: "\(libraryTrackCount)", detail: libraryTrackCount == 1 ? "track indexed" : "tracks indexed")
            PlanFactCard(title: "Latest Set", value: latestSet?.name ?? "None yet", detail: latestSet == nil ? "Generate your first pass" : "Most recent saved crate")
        }
    }

    private var composerSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                promptComposer
                promptSidebar
                    .frame(width: 320)
            }

            VStack(alignment: .leading, spacing: 16) {
                promptComposer
                promptSidebar
            }
        }
    }

    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Brief")
                        .font(.headline)
                    Text("Name it, shape the arc, and give the planner enough texture to make choices you would actually play.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset") {
                    clearPrompt()
                }
                .buttonStyle(.bordered)
                .disabled(isPlanning)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(presets) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preset.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(preset.caption)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                TagPill(text: "\(preset.duration) min")
                                TagPill(text: preset.setName)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Late set / room name / occasion", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Stepper("\(duration) minutes", value: $duration, in: 10...360, step: 5)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxWidth: 220)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $description)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 240)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.09), Color.white.opacity(0.06), Color.teal.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(alignment: .topLeading) {
                        if normalizedDescription.isEmpty {
                            Text("Example: 75 minute warehouse set, percussive and tense, keep the floor locked early, peak late, then ease off without losing momentum.")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 14)
                                .padding(.top, 15)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                Button {
                    Task { await planSet() }
                } label: {
                    Label(isPlanning ? "Generating..." : "Generate Set", systemImage: "wand.and.stars.inverse")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isPlanning || normalizedDescription.isEmpty)

                if !resolvedSetName().isEmpty {
                    Text("Will save as \(resolvedSetName())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var promptSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("What The Model Actually Does")
                    .font(.headline)
                SidebarNote(icon: "text.alignleft", title: "Reads the brief", detail: "It interprets genre shorthand, desired energy curve, and overall shape.")
                SidebarNote(icon: "square.stack.3d.up", title: "Ranks your local catalog", detail: "DeepCrate prefilters your library and sends a compact track catalog to the model.")
                SidebarNote(icon: "link", title: "Returns only track IDs", detail: "Swift validates the IDs, fills holes, and rescues rough transitions afterward.")
            }
            .liquidCard(cornerRadius: LiquidMetrics.compactRadius, material: .thinMaterial, contentPadding: 14, shadowOpacity: 0.04)

            VStack(alignment: .leading, spacing: 10) {
                Text("Model Notes")
                    .font(.headline)
                if settings.plannerMode == .localServer {
                    Text("Start with a strong local instruct model. For this app, Qwen 8B is a sensible default before you test larger models.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TagPill(text: settings.localModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No model set" : settings.localModelName)
                    TagPill(text: settings.localModelEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No endpoint" : settings.localModelEndpoint)
                } else {
                    Text("Apple On-Device is the clean fallback when you do not want another local service running in the background.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TagPill(text: "Private")
                    TagPill(text: "Zero extra setup")
                }
            }
            .liquidCard(cornerRadius: LiquidMetrics.compactRadius, material: .thinMaterial, contentPadding: 14, shadowOpacity: 0.04)
        }
    }

    private var messageBanner: some View {
        Label(inlineMessage, systemImage: inlineMessageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(inlineMessageIsError ? .red : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                    .strokeBorder((inlineMessageIsError ? Color.red : Color.white).opacity(0.16), lineWidth: 1)
            )
    }

    private var plannerBadgeText: String {
        settings.plannerMode == .localServer ? "Local server + model" : "Built-in Apple planning"
    }

    private var libraryTrackCount: Int {
        appState.libraryTracks.count
    }

    private var targetTrackCount: Int {
        max(6, min(24, duration / 5))
    }

    private var normalizedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var latestSet: SetSummary? {
        appState.setSummaries.max(by: { $0.id < $1.id })
    }

    private func plannerDetailPanel(
        title: String,
        subtitle: String,
        tone: Color,
        symbol: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tone)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func plannerModeCard(
        mode: AppSettings.PlannerMode,
        icon: String,
        accent: [Color],
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            settings.plannerMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .frame(width: 22)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    if settings.plannerMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: settings.plannerMode == mode
                        ? [accent[0], accent[1], Color.white.opacity(0.10)]
                        : [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                    .strokeBorder(
                        settings.plannerMode == mode ? Color.white.opacity(0.32) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func planSet() async {
        isPlanning = true
        appState.statusMessage = "Planning set..."
        defer { isPlanning = false }

        let localDescription = normalizedDescription
        if localDescription.isEmpty {
            inlineMessageIsError = true
            inlineMessage = "Add a prompt before generating."
            appState.statusMessage = "Set planning needs a prompt."
            return
        }

        let localName = resolvedSetName()
        let localDuration = duration
        name = localName

        var preflightWarning: String?
        do {
            let tracks = try await ensureLibraryTracks()
            let availability = LocalApplePlanner().evaluateGenreAvailability(
                description: localDescription,
                tracks: tracks
            )
            if let warning = availability.warningMessage {
                preflightWarning = warning
                inlineMessageIsError = false
                inlineMessage = "Heads-up: \(warning)"
                appState.statusMessage = warning
            }
        } catch {
            appState.statusMessage = "Could not pre-check genre availability: \(error.localizedDescription)"
        }

        switch settings.plannerMode {
        case .localApple:
            await planWithAppleModel(
                description: localDescription,
                name: localName,
                duration: localDuration,
                preflightWarning: preflightWarning
            )
        case .localServer:
            await planWithLocalModel(
                description: localDescription,
                name: localName,
                duration: localDuration,
                preflightWarning: preflightWarning
            )
        }
    }

    private func planWithAppleModel(
        description: String,
        name: String,
        duration: Int,
        preflightWarning: String?
    ) async {
        do {
            let tracks = try await ensureLibraryTracks()
            let planner = LocalApplePlanner()
            let ids = try await planner.planTrackIDs(description: description, durationMinutes: duration, tracks: tracks)
            if ids.isEmpty {
                appState.statusMessage = "Apple planner returned no tracks."
                return
            }

            try await Task.detached {
                try LocalDatabase.shared.saveSet(
                    name: name,
                    description: description,
                    duration: duration,
                    trackIDs: ids
                )
            }.value
            appState.statusMessage = "Created set \(name) with Apple On-Device"
            inlineMessageIsError = false
            inlineMessage = preflightWarning.map { "Created set \(name). Note: \($0)" } ?? "Created set \(name)"
            await refreshSets()
        } catch {
            appState.statusMessage = "Apple planning failed: \(error.localizedDescription)"
            inlineMessageIsError = true
            inlineMessage = "Apple planning failed: \(error.localizedDescription)"
        }
    }

    private func planWithLocalModel(
        description: String,
        name: String,
        duration: Int,
        preflightWarning: String?
    ) async {
        do {
            let tracks = try await ensureLibraryTracks()
            let endpoint = resolvedLocalModelEndpoint()
            let model = resolvedLocalModelName()
            let token = resolvedLocalModelToken()
            let planner = LocalModelPlanner()
            let ids = try await planner.planTrackIDs(
                description: description,
                durationMinutes: duration,
                tracks: tracks,
                endpoint: endpoint,
                model: model,
                authToken: token
            )
            if ids.isEmpty {
                appState.statusMessage = "Local model returned no tracks."
                return
            }

            try await Task.detached {
                try LocalDatabase.shared.saveSet(
                    name: name,
                    description: description,
                    duration: duration,
                    trackIDs: ids
                )
            }.value
            appState.statusMessage = "Created set \(name) with local model server"
            inlineMessageIsError = false
            inlineMessage = preflightWarning.map { "Created set \(name). Note: \($0)" } ?? "Created set \(name)"
            await refreshSets()
        } catch {
            appState.statusMessage = "Local model planning failed: \(error.localizedDescription)"
            inlineMessageIsError = true
            inlineMessage = "Local model planning failed: \(error.localizedDescription)"
        }
    }

    private func refreshSets() async {
        do {
            let sets = try await Task.detached {
                try LocalDatabase.shared.listSets()
            }.value
            appState.setSummaries = sets
        } catch {
            appState.statusMessage = "Failed to load sets: \(error.localizedDescription)"
        }
    }

    private func ensureLibraryTracks() async throws -> [Track] {
        if !appState.libraryTracks.isEmpty {
            return appState.libraryTracks
        }
        let tracks = try await Task.detached {
            try LocalDatabase.shared.loadTracks()
        }.value
        appState.libraryTracks = tracks
        return tracks
    }

    private func resolvedLocalModelEndpoint() -> String {
        let fromSettings = settings.localModelEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromSettings.isEmpty {
            return fromSettings
        }
        return envValue("LOCAL_MODEL_ENDPOINT") ?? "http://127.0.0.1:8080"
    }

    private func resolvedLocalModelName() -> String {
        let fromSettings = settings.localModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromSettings.isEmpty {
            return fromSettings
        }
        return envValue("LOCAL_MODEL_NAME") ?? "Qwen/Qwen3-8B-Instruct"
    }

    private func resolvedLocalModelToken() -> String {
        let fromSettings = settings.localModelToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromSettings.isEmpty {
            return fromSettings
        }
        return envValue("LOCAL_MODEL_TOKEN") ?? ""
    }

    private func envValue(_ key: String) -> String? {
        for envURL in AppRuntime.envFileCandidates {
            guard let content = try? String(contentsOf: envURL, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                    return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }

    private func clearPrompt() {
        name = ""
        duration = 60
        description = ""
    }

    private func applyPreset(_ preset: PromptPreset) {
        name = preset.setName
        duration = preset.duration
        description = preset.prompt
    }

    private func resolvedSetName() -> String {
        let baseName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = baseName.isEmpty ? defaultSetName() : baseName
        let existing = Set(appState.setSummaries.map { $0.name.lowercased() })

        if !existing.contains(seed.lowercased()) {
            return seed
        }

        var index = 2
        while true {
            let candidate = "\(seed) \(index)"
            if !existing.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }

    private func defaultSetName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm"
        return "Set \(formatter.string(from: Date()))"
    }
}

private struct PlanFactCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.16), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LiquidMetrics.compactRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SidebarNote: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
