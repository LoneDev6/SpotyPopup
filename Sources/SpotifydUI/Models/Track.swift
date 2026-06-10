import Foundation

struct Track: Codable {
    let name: String
    let artists: [Artist]
    let album: Album

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
}
