import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum LocalPlanningError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Foundation Model is unavailable on this Mac."
        }
    }
}

struct LocalApplePlanner {
    func planTrackIDs(description: String, durationMinutes: Int, tracks: [Track]) async throws -> [Int] {
        let fallback = fallbackSelection(durationMinutes: durationMinutes, tracks: tracks)

#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                throw LocalPlanningError.modelUnavailable
            }

            let catalog = tracks.prefix(300).map { track in
                "\(track.id)|\(track.artist)|\(track.title)|\(Int(track.bpm))|\(track.key)|\(String(format: "%.2f", track.energy))"
            }.joined(separator: "\n")

            let prompt = """
            You are planning a DJ set. Return ONLY strict JSON in this format:
            {"track_ids":[1,2,3]}

            Rules:
            - Use only IDs from the catalog.
            - Preserve musical flow across BPM, key, and energy.
            - Prefer around \(max(6, min(24, durationMinutes / 5))) tracks.
            - No explanation, no markdown, only JSON.

            User request:
            \(description)

            Catalog:
            \(catalog)
            """

            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            if let ids = parseIDs(from: response.content), !ids.isEmpty {
                let valid = ids.filter { id in tracks.contains(where: { $0.id == id }) }
                if !valid.isEmpty {
                    return Array(valid.prefix(max(6, min(24, durationMinutes / 5))))
                }
            }
        }
#endif

        return fallback
    }

    private func fallbackSelection(durationMinutes: Int, tracks: [Track]) -> [Int] {
        guard !tracks.isEmpty else { return [] }
        let targetCount = max(6, min(24, durationMinutes / 5))
        let sorted = tracks.sorted { lhs, rhs in
            if lhs.bpm != rhs.bpm { return lhs.bpm < rhs.bpm }
            return lhs.energy < rhs.energy
        }
        return Array(sorted.prefix(targetCount)).map(\.id)
    }

    private func parseIDs(from raw: String) -> [Int]? {
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else { return nil }

        if let direct = try? JSONDecoder().decode(TrackIDEnvelope.self, from: data) {
            return direct.trackIDs
        }

        guard
            let start = cleaned.firstIndex(of: "{"),
            let end = cleaned.lastIndex(of: "}")
        else {
            return nil
        }

        let snippet = String(cleaned[start...end])
        guard let snippetData = snippet.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TrackIDEnvelope.self, from: snippetData).trackIDs
    }

    private func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            trimmed = trimmed.replacingOccurrences(of: "```json", with: "")
            trimmed = trimmed.replacingOccurrences(of: "```", with: "")
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TrackIDEnvelope: Decodable {
    let trackIDs: [Int]

    enum CodingKeys: String, CodingKey {
        case trackIDs = "track_ids"
    }
}
