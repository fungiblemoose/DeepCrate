import Foundation

struct Track: Identifiable, Hashable {
    let id: Int
    var artist: String
    var title: String
    var bpm: Double
    var key: String
    var energy: Double

    init(id: Int, artist: String, title: String, bpm: Double, key: String, energy: Double) {
        self.id = id
        self.artist = artist
        self.title = title
        self.bpm = bpm
        self.key = key
        self.energy = energy
    }
}

struct SetPlan: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var durationMinutes: Int
    var tracks: [Track]

    init(id: UUID = UUID(), name: String, description: String, durationMinutes: Int, tracks: [Track] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.durationMinutes = durationMinutes
        self.tracks = tracks
    }
}

struct SetSummary: Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String
    var targetDuration: Int
}

struct SetTrackRow: Identifiable, Hashable {
    let id: Int
    var position: Int
    var artist: String
    var title: String
    var bpm: Double
    var key: String
    var energy: Double
    var transition: String
}

struct GapSuggestion: Identifiable, Hashable {
    let id: UUID
    var fromTrack: String
    var toTrack: String
    var score: Double
    var suggestedBPM: Double
    var suggestedKey: String

    init(id: UUID = UUID(), fromTrack: String, toTrack: String, score: Double, suggestedBPM: Double, suggestedKey: String) {
        self.id = id
        self.fromTrack = fromTrack
        self.toTrack = toTrack
        self.score = score
        self.suggestedBPM = suggestedBPM
        self.suggestedKey = suggestedKey
    }
}

struct DiscoverSuggestion: Identifiable, Hashable {
    let id: UUID
    var artist: String
    var title: String
    var bpm: Double
    var energy: Double
    var url: String

    init(id: UUID = UUID(), artist: String, title: String, bpm: Double, energy: Double, url: String) {
        self.id = id
        self.artist = artist
        self.title = title
        self.bpm = bpm
        self.energy = energy
        self.url = url
    }
}
