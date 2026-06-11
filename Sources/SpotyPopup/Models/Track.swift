import Foundation

struct Track: Codable, Identifiable {
    let id: String
    let name: String
    let artists: [Artist]
    let album: Album
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
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
