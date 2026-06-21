import Foundation

enum SpotifyWebMemoryPolicy: String {
    case instant
    case after30Seconds
    case never
}

enum AppSettings {
    private static let closeSpotifyWebViewOnBackKey = "close_spotify_webview_on_back"
    private static let spotifyWebMemoryPolicyKey = "spotify_web_memory_policy"
    private static let spotifyVolumeKey = "spotify_volume"
    private static let spotifyWebLastURLKey = "spotify_web_last_url"

    static var closeSpotifyWebViewOnBack: Bool {
        get {
            spotifyWebMemoryPolicy == .instant
        }
        set {
            spotifyWebMemoryPolicy = newValue ? .instant : .never
        }
    }

    static var spotifyWebMemoryPolicy: SpotifyWebMemoryPolicy {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: spotifyWebMemoryPolicyKey),
               let policy = SpotifyWebMemoryPolicy(rawValue: rawValue) {
                return policy
            }

            if UserDefaults.standard.object(forKey: closeSpotifyWebViewOnBackKey) != nil,
               UserDefaults.standard.bool(forKey: closeSpotifyWebViewOnBackKey) == false {
                return .never
            }

            return .instant
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: spotifyWebMemoryPolicyKey)
            UserDefaults.standard.set(newValue == .instant, forKey: closeSpotifyWebViewOnBackKey)
        }
    }

    static var spotifyVolume: Int {
        get {
            if UserDefaults.standard.object(forKey: spotifyVolumeKey) == nil {
                return 50
            }

            return max(0, min(100, UserDefaults.standard.integer(forKey: spotifyVolumeKey)))
        }
        set {
            UserDefaults.standard.set(max(0, min(100, newValue)), forKey: spotifyVolumeKey)
        }
    }

    static var spotifyWebLastURL: URL? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: spotifyWebLastURLKey) else { return nil }
            return URL(string: rawValue)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: spotifyWebLastURLKey)
        }
    }
}
