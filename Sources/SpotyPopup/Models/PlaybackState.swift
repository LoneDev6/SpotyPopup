import Foundation

struct PlaybackState: Codable {
    let isPlaying: Bool
    let item: Track?
    let device: Device?
    let shuffleState: Bool?
    let progressMs: Int

    struct Device: Codable {
        let name: String
        let type: String
    }

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
        case device
        case shuffleState = "shuffle_state"
        case progressMs = "progress_ms"
    }
}
