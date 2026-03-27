import Foundation

enum LocalModelPlannerError: LocalizedError {
    case missingEndpoint
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Local model endpoint is missing."
        case .invalidResponse:
            return "Local model returned invalid data."
        case .requestFailed(let message):
            return message
        }
    }
}

struct LocalModelPlanResult {
    let trackIDs: [Int]
    /// How many IDs the model returned were valid library tracks (before fallback padding).
    let validModelIDCount: Int
}

struct LocalModelPlanner {
    private let fallbackPlanner = LocalApplePlanner()

    func planTrackIDs(
        description: String,
        durationMinutes: Int,
        tracks: [Track],
        endpoint: String,
        model: String,
        authToken: String
    ) async throws -> LocalModelPlanResult {
        let requestURL = try resolvedEndpointURL(endpoint)
        let selectedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            throw LocalModelPlannerError.requestFailed("Choose a local model name before planning.")
        }

        let package = fallbackPlanner.promptPackage(
            description: description,
            durationMinutes: durationMinutes,
            tracks: tracks
        )

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionsRequest(
                model: selectedModel,
                messages: [
                    .init(role: "system", content: "You are an expert DJ set planner. Return strict JSON only."),
                    .init(role: "user", content: package.prompt),
                ],
                temperature: 0.45,
                maxTokens: 1200
            )
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LocalModelPlannerError.requestFailed("Could not reach local model server: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            throw LocalModelPlannerError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw LocalModelPlannerError.requestFailed("Local model server error (\(http.statusCode)): \(body)")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let raw = decoded.choices.first?.message.content else {
            throw LocalModelPlannerError.invalidResponse
        }

        let planned = parseIDs(from: raw) ?? []
        let trackIDSet = Set(tracks.map(\.id))
        let validModelIDCount = planned.filter { trackIDSet.contains($0) }.count
        let normalized = fallbackPlanner.normalizePlannedIDs(
            planned,
            description: description,
            durationMinutes: durationMinutes,
            tracks: tracks
        )
        return LocalModelPlanResult(trackIDs: normalized, validModelIDCount: validModelIDCount)
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

    private func resolvedEndpointURL(_ rawEndpoint: String) throws -> URL {
        let trimmed = rawEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LocalModelPlannerError.missingEndpoint
        }

        let baseString = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let url = URL(string: baseString), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw LocalModelPlannerError.requestFailed("Local model endpoint is invalid.")
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath: String
        switch trimmedPath {
        case "", "/":
            normalizedPath = "/v1/chat/completions"
        case "v1":
            normalizedPath = "/v1/chat/completions"
        case "v1/chat":
            normalizedPath = "/v1/chat/completions"
        case "chat/completions", "v1/chat/completions":
            normalizedPath = "/" + trimmedPath
        default:
            normalizedPath = "/" + trimmedPath + "/v1/chat/completions"
        }
        components.path = normalizedPath.replacingOccurrences(of: "//", with: "/")
        guard let normalized = components.url else {
            throw LocalModelPlannerError.requestFailed("Local model endpoint is invalid.")
        }
        return normalized
    }
}

private struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }

    let choices: [Choice]
}

private struct TrackIDEnvelope: Decodable {
    let trackIDs: [Int]

    enum CodingKeys: String, CodingKey {
        case trackIDs = "track_ids"
    }
}
