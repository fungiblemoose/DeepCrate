import Foundation

@MainActor
final class AppSettings: ObservableObject {
    enum PlannerMode: String, CaseIterable, Identifiable {
        case localServer = "Local Model Server"
        case localApple = "Apple On-Device"

        var id: String { rawValue }
    }

    enum TransitionRiskMode: String, CaseIterable, Identifiable {
        case safe = "Safe"
        case balanced = "Balanced"
        case bold = "Bold"

        var id: String { rawValue }
    }

    @Published var localModelEndpoint: String {
        didSet { UserDefaults.standard.set(localModelEndpoint, forKey: Keys.localModelEndpoint) }
    }
    @Published var localModelName: String {
        didSet { UserDefaults.standard.set(localModelName, forKey: Keys.localModelName) }
    }
    @Published var localModelToken: String {
        didSet { UserDefaults.standard.set(localModelToken, forKey: Keys.localModelToken) }
    }
    @Published var spotifyClientID: String {
        didSet { UserDefaults.standard.set(spotifyClientID, forKey: Keys.spotifyClientID) }
    }
    @Published var spotifyClientSecret: String {
        didSet { UserDefaults.standard.set(spotifyClientSecret, forKey: Keys.spotifyClientSecret) }
    }
    @Published var databasePath: String {
        didSet { UserDefaults.standard.set(databasePath, forKey: Keys.databasePath) }
    }
    @Published var plannerMode: PlannerMode {
        didSet { UserDefaults.standard.set(plannerMode.rawValue, forKey: Keys.plannerMode) }
    }
    @Published var transitionRiskMode: TransitionRiskMode {
        didSet { UserDefaults.standard.set(transitionRiskMode.rawValue, forKey: Keys.transitionRiskMode) }
    }

    init() {
        self.localModelEndpoint = UserDefaults.standard.string(forKey: Keys.localModelEndpoint)
            ?? AppSettings.envValue("LOCAL_MODEL_ENDPOINT")
            ?? "http://127.0.0.1:8080"
        self.localModelName = UserDefaults.standard.string(forKey: Keys.localModelName)
            ?? AppSettings.envValue("LOCAL_MODEL_NAME")
            ?? "Qwen/Qwen3-8B-Instruct"
        self.localModelToken = UserDefaults.standard.string(forKey: Keys.localModelToken)
            ?? AppSettings.envValue("LOCAL_MODEL_TOKEN")
            ?? ""
        self.spotifyClientID = UserDefaults.standard.string(forKey: Keys.spotifyClientID)
            ?? AppSettings.envValue("SPOTIFY_CLIENT_ID")
            ?? ""
        self.spotifyClientSecret = UserDefaults.standard.string(forKey: Keys.spotifyClientSecret)
            ?? AppSettings.envValue("SPOTIFY_CLIENT_SECRET")
            ?? ""
        self.databasePath = UserDefaults.standard.string(forKey: Keys.databasePath)
            ?? AppSettings.envValue("DATABASE_PATH")
            ?? AppRuntime.defaultDatabaseSettingValue

        let storedMode = UserDefaults.standard.string(forKey: Keys.plannerMode)
        self.plannerMode = PlannerMode(rawValue: storedMode ?? "") ?? .localServer

        let storedRisk = UserDefaults.standard.string(forKey: Keys.transitionRiskMode)
        self.transitionRiskMode = TransitionRiskMode(rawValue: storedRisk ?? "") ?? .balanced
    }

    private static func envValue(_ key: String) -> String? {
        for envURL in AppRuntime.envFileCandidates {
            guard let content = try? String(contentsOf: envURL, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2,
                   parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                    return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
}

private enum Keys {
    static let localModelEndpoint = "settings.localModelEndpoint"
    static let localModelName = "settings.localModelName"
    static let localModelToken = "settings.localModelToken"
    static let spotifyClientID = "settings.spotifyClientID"
    static let spotifyClientSecret = "settings.spotifyClientSecret"
    static let databasePath = "settings.databasePath"
    static let plannerMode = "settings.plannerMode"
    static let transitionRiskMode = "settings.transitionRiskMode"
}
