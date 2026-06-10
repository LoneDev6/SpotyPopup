import Foundation

struct PlaylistsResponse: Codable {
    let items: [Playlist]
}

struct Playlist: Codable, Identifiable {
    let id: String
    let name: String
    let images: [Track.Image]
    let tracks: TracksInfo

    struct TracksInfo: Codable {
        let total: Int
    }

    var imageURL: String? {
        images.first?.url
    }
}

struct PlaylistTracksResponse: Codable {
    let items: [PlaylistTrackItem]
}

struct PlaylistTrackItem: Codable, Identifiable {
    let track: Track?

    var id: String {
        track?.id ?? UUID().uuidString
    }
}

struct QueueResponse: Codable {
    let currentlyPlaying: Track?
    let queue: [Track]

    enum CodingKeys: String, CodingKey {
        case currentlyPlaying = "currently_playing"
        case queue
    }
}
