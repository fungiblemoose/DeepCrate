import Foundation

enum SpotifyDiscoveryError: LocalizedError {
    case missingCredentials
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Spotify credentials are missing. Open Settings and add a client ID and client secret."
        case .invalidURL:
            return "Spotify request URL is invalid."
        case .invalidResponse:
            return "Spotify returned an unexpected response."
        case .unauthorized:
            return "Spotify authorization failed. Check your client ID and client secret."
        case .rateLimited:
            return "Spotify rate limit hit. Wait a moment and try again."
        case .requestFailed(let message):
            return message
        }
    }
}

struct SpotifyDiscoveryService: Sendable {
    static let shared = SpotifyDiscoveryService()

    func discover(for gap: GapSuggestion, genre: String, limit: Int) async throws -> [DiscoverSuggestion] {
        let clientID = UserDefaults.standard.string(forKey: "settings.spotifyClientID")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let clientSecret = UserDefaults.standard.string(forKey: "settings.spotifyClientSecret")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw SpotifyDiscoveryError.missingCredentials
        }

        let token = try await SpotifyTokenStore.shared.accessToken(
            clientID: clientID,
            clientSecret: clientSecret
        )

        let searchLimit = min(max(limit * 4, 20), 50)
        let searchQueries = discoveryQueries(genre: genre)
        var tracksByID: [String: SpotifyTrackItem] = [:]

        for query in searchQueries {
            let response = try await searchTracks(
                query: query,
                limit: searchLimit,
                accessToken: token
            )
            for item in response.tracks.items where tracksByID[item.id] == nil {
                tracksByID[item.id] = item
            }
            if tracksByID.count >= searchLimit {
                break
            }
        }

        let trackItems = Array(tracksByID.values)
        guard !trackItems.isEmpty else {
            return []
        }

        let featuresByID = try await audioFeatures(
            ids: trackItems.map(\.id),
            accessToken: token
        )

        return rankedSuggestions(
            trackItems: trackItems,
            featuresByID: featuresByID,
            gap: gap,
            limit: limit
        )
    }

    private func discoveryQueries(genre: String) -> [String] {
        let trimmedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGenre.isEmpty else {
            return ["electronic"]
        }
        return [
            "genre:\(trimmedGenre)",
            trimmedGenre,
        ]
    }

    private func searchTracks(
        query: String,
        limit: Int,
        accessToken: String
    ) async throws -> SpotifySearchResponse {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw SpotifyDiscoveryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return try await perform(request, decode: SpotifySearchResponse.self)
    }

    private func audioFeatures(
        ids: [String],
        accessToken: String
    ) async throws -> [String: SpotifyAudioFeature] {
        guard !ids.isEmpty else { return [:] }

        var results: [String: SpotifyAudioFeature] = [:]
        for chunk in ids.chunked(into: 100) {
            var components = URLComponents(string: "https://api.spotify.com/v1/audio-features")
            components?.queryItems = [
                URLQueryItem(name: "ids", value: chunk.joined(separator: ",")),
            ]

            guard let url = components?.url else {
                throw SpotifyDiscoveryError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let response = try await perform(request, decode: SpotifyAudioFeaturesResponse.self)
            for feature in response.audioFeatures.compactMap({ $0 }) {
                results[feature.id] = feature
            }
        }

        return results
    }

    private func rankedSuggestions(
        trackItems: [SpotifyTrackItem],
        featuresByID: [String: SpotifyAudioFeature],
        gap: GapSuggestion,
        limit: Int
    ) -> [DiscoverSuggestion] {
        var strictMatches: [DiscoverSuggestion] = []
        var fallbackMatches: [DiscoverSuggestion] = []

        for item in trackItems {
            guard let feature = featuresByID[item.id] else { continue }

            var bpm = feature.tempo
            if gap.suggestedBPM > 140, bpm < 100 {
                bpm *= 2
            } else if gap.suggestedBPM > 0, gap.suggestedBPM < 100, bpm > 140 {
                bpm /= 2
            }

            let tempoDelta = gap.suggestedBPM > 0 ? abs(bpm - gap.suggestedBPM) : 0
            let energyDelta = gap.suggestedEnergy > 0 ? abs(feature.energy - gap.suggestedEnergy) : 0
            let trackCamelot = spotifyKeyToCamelot(key: feature.key, mode: feature.mode)

            let tempoScore = gap.suggestedBPM > 0
                ? max(0, 1.0 - (tempoDelta / 8.0))
                : 0.6
            let energyScore = gap.suggestedEnergy > 0
                ? max(0, 1.0 - (energyDelta / 0.35))
                : 0.6

            let matchScore: Double
            let targetKey = gap.suggestedKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !targetKey.isEmpty, let camelot = trackCamelot {
                let keyScore = camelotCompatibility(targetKey, camelot)
                matchScore = min(1.0, (0.40 * keyScore) + (0.35 * tempoScore) + (0.25 * energyScore))
            } else {
                matchScore = min(1.0, (0.65 * tempoScore) + (0.35 * energyScore))
            }

            let suggestion = DiscoverSuggestion(
                artist: item.artists.map(\.name).joined(separator: ", "),
                title: item.name,
                album: item.album.name,
                bpm: round(bpm * 10.0) / 10.0,
                energy: round(feature.energy * 100.0) / 100.0,
                camelotKey: trackCamelot ?? "",
                artworkURL: item.album.images.first?.url ?? "",
                url: item.externalURLs.spotify,
                matchScore: round(matchScore * 100.0) / 100.0,
                tempoDelta: round(tempoDelta * 10.0) / 10.0,
                energyDelta: round(energyDelta * 100.0) / 100.0
            )

            let withinTempo = gap.suggestedBPM <= 0 || tempoDelta <= 5.0
            let withinEnergy = gap.suggestedEnergy <= 0 || energyDelta <= 0.2
            if withinTempo && withinEnergy {
                strictMatches.append(suggestion)
            } else {
                fallbackMatches.append(suggestion)
            }
        }

        let sorter: (DiscoverSuggestion, DiscoverSuggestion) -> Bool = { lhs, rhs in
            if lhs.matchScore != rhs.matchScore {
                return lhs.matchScore > rhs.matchScore
            }
            if lhs.tempoDelta != rhs.tempoDelta {
                return lhs.tempoDelta < rhs.tempoDelta
            }
            if lhs.energyDelta != rhs.energyDelta {
                return lhs.energyDelta < rhs.energyDelta
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        strictMatches.sort(by: sorter)
        fallbackMatches.sort(by: sorter)

        var results = Array(strictMatches.prefix(limit))
        if results.count < limit {
            let supplemental = fallbackMatches.prefix(limit - results.count)
            results.append(contentsOf: supplemental)
        }
        return results
    }

    // Spotify pitch class (0=C … 11=B) + mode (0=minor, 1=major) → Camelot notation.
    // Arrays are indexed by pitch class.
    private static let majorCamelot = ["8B","3B","10B","5B","12B","7B","2B","9B","4B","11B","6B","1B"]
    private static let minorCamelot = ["5A","12A","7A","2A","9A","4A","11A","6A","1A","8A","3A","10A"]

    private func spotifyKeyToCamelot(key: Int, mode: Int) -> String? {
        guard (0...11).contains(key) else { return nil }
        return mode == 1
            ? SpotifyDiscoveryService.majorCamelot[key]
            : SpotifyDiscoveryService.minorCamelot[key]
    }

    private func parseCamelot(_ value: String) -> (number: Int, letter: Character)? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let letter = normalized.last, letter == "A" || letter == "B" else { return nil }
        guard let number = Int(normalized.dropLast()), (1...12).contains(number) else { return nil }
        return (number, letter)
    }

    private func camelotCompatibility(_ lhs: String, _ rhs: String) -> Double {
        guard let a = parseCamelot(lhs), let b = parseCamelot(rhs) else { return 0.5 }
        if a.number == b.number && a.letter == b.letter { return 1.0 }
        if a.number == b.number { return 0.8 }
        if a.letter == b.letter {
            let distance = min(abs(a.number - b.number), 12 - abs(a.number - b.number))
            if distance == 1 { return 0.8 }
            if distance == 2 { return 0.5 }
        }
        return 0.2
    }

    private func perform<Response: Decodable>(_ request: URLRequest, decode type: Response.Type) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyDiscoveryError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw SpotifyDiscoveryError.requestFailed("Spotify response decode failed: \(error.localizedDescription)")
            }
        case 401:
            throw SpotifyDiscoveryError.unauthorized
        case 429:
            throw SpotifyDiscoveryError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SpotifyDiscoveryError.requestFailed(
                body.isEmpty
                    ? "Spotify request failed with status \(httpResponse.statusCode)."
                    : "Spotify request failed (\(httpResponse.statusCode)): \(body)"
            )
        }
    }
}

actor SpotifyTokenStore {
    static let shared = SpotifyTokenStore()

    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast
    private var credentialFingerprint: String = ""

    func accessToken(clientID: String, clientSecret: String) async throws -> String {
        let fingerprint = "\(clientID)|\(clientSecret)"
        if credentialFingerprint == fingerprint,
           let cachedToken,
           tokenExpiry.timeIntervalSinceNow > 60 {
            return cachedToken
        }

        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyDiscoveryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let authValue = Data("\(clientID):\(clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(authValue)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyDiscoveryError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            let token = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            cachedToken = token.accessToken
            tokenExpiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
            credentialFingerprint = fingerprint
            return token.accessToken
        case 401:
            throw SpotifyDiscoveryError.unauthorized
        case 429:
            throw SpotifyDiscoveryError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SpotifyDiscoveryError.requestFailed(
                body.isEmpty
                    ? "Spotify token request failed with status \(httpResponse.statusCode)."
                    : "Spotify token request failed (\(httpResponse.statusCode)): \(body)"
            )
        }
    }
}

private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTrackContainer
}

private struct SpotifyTrackContainer: Decodable {
    let items: [SpotifyTrackItem]
}

private struct SpotifyTrackItem: Decodable {
    let id: String
    let name: String
    let album: SpotifyAlbum
    let artists: [SpotifyArtist]
    let externalURLs: SpotifyExternalURLs

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case album
        case artists
        case externalURLs = "external_urls"
    }
}

private struct SpotifyAlbum: Decodable {
    let name: String
    let images: [SpotifyImage]
}

private struct SpotifyArtist: Decodable {
    let name: String
}

private struct SpotifyImage: Decodable {
    let url: String
}

private struct SpotifyExternalURLs: Decodable {
    let spotify: String
}

private struct SpotifyAudioFeaturesResponse: Decodable {
    let audioFeatures: [SpotifyAudioFeature?]

    enum CodingKeys: String, CodingKey {
        case audioFeatures = "audio_features"
    }
}

private struct SpotifyAudioFeature: Decodable {
    let id: String
    let tempo: Double
    let energy: Double
    let key: Int
    let mode: Int
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return chunks
    }
}
