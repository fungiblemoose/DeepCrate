import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                plannerCard
                storageCard
                discoveryCard
            }
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(width: 760, height: 640)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Tune the planner, point DeepCrate at a local model server, and keep the rest of the app out of your way.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var plannerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Planner")
                    .font(.headline)
                Spacer()
                Text("Primary path")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Picker("Mode", selection: $settings.plannerMode) {
                ForEach(AppSettings.PlannerMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 12) {
                SettingsField(
                    title: "Local Endpoint",
                    caption: "Point this at your local chat-completions server. Example: `http://127.0.0.1:8080`",
                    text: $settings.localModelEndpoint,
                    prompt: "http://127.0.0.1:8080"
                )

                SettingsField(
                    title: "Model Name",
                    caption: "Pick the model your local server should load by default. Start with `Qwen/Qwen3-8B-Instruct`.",
                    text: $settings.localModelName,
                    prompt: "Qwen/Qwen3-8B-Instruct"
                )

                SettingsField(
                    title: "Optional Auth Token",
                    caption: "Leave this blank for local servers that do not require auth.",
                    text: $settings.localModelToken,
                    prompt: "token if your server needs one",
                    secure: true
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Transition Risk")
                    .font(.subheadline.weight(.semibold))
                Picker("Transition Risk", selection: $settings.transitionRiskMode) {
                    ForEach(AppSettings.TransitionRiskMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text("Safe prioritizes cleaner handoffs. Bold tolerates more aggressive jumps if the overall story works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                SettingsHintPill(text: settings.plannerMode.rawValue)
                SettingsHintPill(text: settings.localModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No local model set" : settings.localModelName)
            }
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.headline)
            SettingsField(
                title: "Database Path",
                caption: "Use a project-local database or point DeepCrate at a shared library file.",
                text: $settings.databasePath,
                prompt: "data/deepcrate.sqlite"
            )
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }

    private var discoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spotify Discovery")
                .font(.headline)

            SettingsField(
                title: "Client ID",
                caption: "Only used for the Discover screen.",
                text: $settings.spotifyClientID,
                prompt: "spotify client id"
            )
            SettingsField(
                title: "Client Secret",
                caption: "Stored locally in user defaults for this personal project.",
                text: $settings.spotifyClientSecret,
                prompt: "spotify client secret",
                secure: true
            )
        }
        .liquidCard(cornerRadius: LiquidMetrics.cardRadius, material: .ultraThinMaterial, contentPadding: 18, shadowOpacity: 0.05)
    }
}

private struct SettingsField: View {
    let title: String
    let caption: String
    @Binding var text: String
    let prompt: String
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if secure {
                SecureField(prompt, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(prompt, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsHintPill: View {
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
