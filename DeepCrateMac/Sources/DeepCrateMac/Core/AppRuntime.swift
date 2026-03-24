import Foundation

enum AppRuntime {
    private static let appSupportSubdirectory = "DeepCrate"

    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    static var envFileCandidates: [URL] {
        if isBundledApp {
            var candidates = [appSupportDirectory.appendingPathComponent(".env")]
            if let bundledResourceRoot {
                candidates.append(bundledResourceRoot.appendingPathComponent(".env"))
            }
            return candidates
        }
        return [devRepoRoot.appendingPathComponent(".env")]
    }

    static var defaultDatabaseSettingValue: String {
        isBundledApp ? defaultDatabaseURL.path : "data/deepcrate.sqlite"
    }

    static var defaultDatabaseURL: URL {
        if isBundledApp {
            return appSupportDirectory
                .appendingPathComponent("data", isDirectory: true)
                .appendingPathComponent("deepcrate.sqlite")
        }

        return devRepoRoot
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("deepcrate.sqlite")
    }

    static func resolveDatabaseURL(configuredPath: String?) -> URL {
        let trimmed = configuredPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }

        let relative = trimmed.isEmpty ? "data/deepcrate.sqlite" : trimmed
        let base = isBundledApp ? appSupportDirectory : devRepoRoot
        return base.appendingPathComponent(relative)
    }

    static var appSupportDirectory: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        let target = base.appendingPathComponent(appSupportSubdirectory, isDirectory: true)
        try? fm.createDirectory(at: target, withIntermediateDirectories: true, attributes: nil)
        return target
    }

    private static var bundledResourceRoot: URL? {
        guard isBundledApp else { return nil }
        return Bundle.main.resourceURL
    }

    private static var devRepoRoot: URL {
        if let located = locateRepoRoot() {
            return located
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .deletingLastPathComponent()
    }

    private static func locateRepoRoot() -> URL? {
        let fm = FileManager.default
        var current = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)

        while true {
            let pyproject = current.appendingPathComponent("pyproject.toml")
            let swiftPackage = current.appendingPathComponent("DeepCrateMac/Package.swift")
            if fm.fileExists(atPath: pyproject.path), fm.fileExists(atPath: swiftPackage.path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }
}
