import Foundation

struct Track: Codable, Identifiable {
    let id: String
    let name: String
    let artists: [Artist]
    let album: Album
    let durationMs: Int?
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, uri
        case durationMs = "duration_ms"
    }

    struct Artist: Codable {
        let name: String
    }

    struct Album: Codable {
        let name: String
        let images: [Image]
    }

    struct Image: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        artists = try container.decode([Artist].self, forKey: .artists)
        album = try container.decode(Album.self, forKey: .album)
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
        uri = try container.decodeIfPresent(String.self, forKey: .uri)

        if let spotifyId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = spotifyId
        } else if let uri {
            id = uri
        } else {
            id = "\(name)-\(artists.map { $0.name }.joined(separator: ","))"
        }
    }

    var artistNames: String {
        artists.map { $0.name }.joined(separator: ", ")
    }

    var albumArtURL: String? {
        album.images.first?.url
    }

    var durationFormatted: String {
        guard let ms = durationMs else { return "--:--" }
        let seconds = ms / 1000
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
