import Foundation

enum AppSettings {
    private static let closeSpotifyWebViewOnBackKey = "close_spotify_webview_on_back"
    private static let spotifyVolumeKey = "spotify_volume"

    static var closeSpotifyWebViewOnBack: Bool {
        get {
            if UserDefaults.standard.object(forKey: closeSpotifyWebViewOnBackKey) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: closeSpotifyWebViewOnBackKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: closeSpotifyWebViewOnBackKey)
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
}
