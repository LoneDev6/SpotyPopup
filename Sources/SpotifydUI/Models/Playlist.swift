import Foundation

struct PlaylistsResponse: Decodable {
    let items: [Playlist]
}

struct Playlist: Identifiable, Decodable {
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

    var isLikedSongs: Bool {
        id == "liked_songs"
    }

    // Spotify uses different key names in different endpoints
    enum CodingKeys: String, CodingKey {
        case id, name, images
        case tracks
        case items // Alternative to tracks in /me/playlists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        images = (try? container.decode([Track.Image].self, forKey: .images)) ?? []

        // Spotify API uses "items" in /me/playlists, "tracks" elsewhere
        if let tracksInfo = try? container.decode(TracksInfo.self, forKey: .items) {
            tracks = tracksInfo
        } else {
            tracks = try container.decode(TracksInfo.self, forKey: .tracks)
        }
    }

    // Manual init for synthetic playlists
    init(id: String, name: String, images: [Track.Image], trackCount: Int) {
        self.id = id
        self.name = name
        self.images = images
        self.tracks = TracksInfo(total: trackCount)
    }

    static func createLikedSongsPlaylist() -> Playlist {
        Playlist(
            id: "liked_songs",
            name: "Liked Songs",
            images: [],
            trackCount: 0
        )
    }
}

struct PlaylistTracksResponse: Codable {
    let items: [PlaylistTrackItem]
    let next: String?
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

struct LikedTracksResponse: Decodable {
    let items: [LikedTrackItem]
    let next: String?
}

struct LikedTrackItem: Decodable {
    let track: Track
}
