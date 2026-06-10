import Foundation

class SpotifyAPI: ObservableObject {
    @Published var currentPlayback: PlaybackState?
    @Published var isLoading = false
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylistTracks: [Track] = []
    @Published var queue: [Track] = []

    private let baseURL = "https://api.spotify.com/v1"
    private var accessToken: String?

    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    func fetchCurrentPlayback() async {
        guard let token = accessToken else { return }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 204 {
                DispatchQueue.main.async {
                    self.currentPlayback = nil
                }
                return
            }

            let playback = try JSONDecoder().decode(PlaybackState.self, from: data)
            DispatchQueue.main.async {
                self.currentPlayback = playback
            }
        } catch {
            print("Failed to fetch playback: \(error)")
        }
    }

    func play() async {
        await sendPlayerCommand(endpoint: "play", method: "PUT")
    }

    func pause() async {
        await sendPlayerCommand(endpoint: "pause", method: "PUT")
    }

    func nextTrack() async {
        await sendPlayerCommand(endpoint: "next", method: "POST")
        try? await Task.sleep(nanoseconds: 500_000_000)
        await fetchCurrentPlayback()
    }

    func previousTrack() async {
        await sendPlayerCommand(endpoint: "previous", method: "POST")
        try? await Task.sleep(nanoseconds: 500_000_000)
        await fetchCurrentPlayback()
    }

    private func sendPlayerCommand(endpoint: String, method: String, body: Data? = nil) async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/\(endpoint)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        do {
            _ = try await URLSession.shared.data(for: request)
            await fetchCurrentPlayback()
        } catch {
            print("Failed to send command \(endpoint): \(error)")
        }
    }

    func fetchPlaylists() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/playlists?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(PlaylistsResponse.self, from: data)
            DispatchQueue.main.async {
                self.playlists = response.items
            }
        } catch {
            print("Failed to fetch playlists: \(error)")
        }
    }

    func fetchPlaylistTracks(playlistId: String) async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/playlists/\(playlistId)/tracks?limit=100")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(PlaylistTracksResponse.self, from: data)
            DispatchQueue.main.async {
                self.currentPlaylistTracks = response.items.compactMap { $0.track }
            }
        } catch {
            print("Failed to fetch playlist tracks: \(error)")
        }
    }

    func playTrack(uri: String) async {
        let body = ["uris": [uri]]
        guard let jsonData = try? JSONEncoder().encode(body) else { return }
        await sendPlayerCommand(endpoint: "play", method: "PUT", body: jsonData)
    }

    func addToQueue(uri: String) async {
        guard let token = accessToken else { return }
        guard let encodedURI = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/queue?uri=\(encodedURI)")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to add to queue: \(error)")
        }
    }

    func fetchQueue() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/queue")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(QueueResponse.self, from: data)
            DispatchQueue.main.async {
                self.queue = response.queue
            }
        } catch {
            print("Failed to fetch queue: \(error)")
        }
    }
}
