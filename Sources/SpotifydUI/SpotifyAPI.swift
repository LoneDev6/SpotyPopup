import Foundation

class SpotifyAPI: ObservableObject {
    @Published var currentPlayback: PlaybackState?
    @Published var isLoading = false
    @Published var playlists: [Playlist] = []
    @Published var currentPlaylistTracks: [Track] = []
    @Published var queue: [Track] = []
    @Published var lastError: String?
    @Published var tracksError: String?
    @Published var isShuffleOn = false

    private let baseURL = "https://api.spotify.com/v1"
    private var accessToken: String?
    var currentPlaylistId: String?
    private var nextTracksURL: String?
    weak var authHandler: SpotifyAuth?

    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    func setAuthHandler(_ handler: SpotifyAuth) {
        self.authHandler = handler
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
        guard let token = accessToken else {
            print("No token for fetchPlaylists")
            DispatchQueue.main.async {
                self.lastError = "No access token - please login"
            }
            return
        }

        print("Fetching playlists...")

        var request = URLRequest(url: URL(string: "\(baseURL)/me/playlists?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("Playlists response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    // Token expired or invalid - try to refresh
                    print("Token error (\(httpResponse.statusCode)), attempting refresh...")
                    await authHandler?.refreshAccessToken()

                    // Retry with new token if available
                    if let newToken = authHandler?.accessToken {
                        self.accessToken = newToken
                        await fetchPlaylists()
                    } else {
                        DispatchQueue.main.async {
                            self.lastError = "Authentication failed - please login again"
                        }
                    }
                    return
                }

                if httpResponse.statusCode != 200 {
                    let errorString = String(data: data, encoding: .utf8) ?? "No error details"
                    print("Playlists error: \(errorString)")
                    DispatchQueue.main.async {
                        self.lastError = "API Error \(httpResponse.statusCode): \(errorString)"
                    }
                    return
                }
            }

            let playlistResponse = try JSONDecoder().decode(PlaylistsResponse.self, from: data)
            print("Decoded \(playlistResponse.items.count) playlists")

            // Create synthetic "Liked Songs" playlist
            let likedSongs = Playlist.createLikedSongsPlaylist()

            DispatchQueue.main.async {
                self.playlists = [likedSongs] + playlistResponse.items
                self.lastError = nil
                print("Set \(self.playlists.count) playlists")
            }
        } catch {
            print("Playlist decode error: \(error)")
            DispatchQueue.main.async {
                self.lastError = "Decode error: \(error.localizedDescription)"
            }
        }
    }

    func fetchPlaylistTracks(playlistId: String, reset: Bool = true) async {
        guard let token = accessToken else {
            await MainActor.run {
                self.tracksError = "No access token"
            }
            return
        }

        if reset {
            currentPlaylistId = playlistId
            await MainActor.run {
                self.currentPlaylistTracks = []
                self.tracksError = nil
            }
        }

        // Special handling for Liked Songs
        let endpoint = playlistId == "liked_songs"
            ? "\(baseURL)/me/tracks?limit=100"
            : "\(baseURL)/playlists/\(playlistId)/tracks?limit=100"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    // Token expired or invalid - try to refresh
                    print("Token error (\(httpResponse.statusCode)), attempting refresh...")
                    await authHandler?.refreshAccessToken()

                    // Retry with new token if available
                    if let newToken = authHandler?.accessToken {
                        self.accessToken = newToken
                        await fetchPlaylistTracks(playlistId: playlistId, reset: reset)
                    } else {
                        await MainActor.run {
                            self.tracksError = "Authentication failed - please login again"
                        }
                    }
                    return
                }

                if httpResponse.statusCode != 200 {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    await MainActor.run {
                        self.tracksError = "HTTP \(httpResponse.statusCode): \(errorString)"
                    }
                    return
                }
            }

            if playlistId == "liked_songs" {
                let decoded = try JSONDecoder().decode(LikedTracksResponse.self, from: data)
                nextTracksURL = decoded.next
                await MainActor.run {
                    if reset {
                        self.currentPlaylistTracks = decoded.items.map { $0.track }
                    } else {
                        self.currentPlaylistTracks.append(contentsOf: decoded.items.map { $0.track })
                    }
                    self.tracksError = nil
                }
            } else {
                let decoded = try JSONDecoder().decode(PlaylistTracksResponse.self, from: data)
                nextTracksURL = decoded.next
                await MainActor.run {
                    if reset {
                        self.currentPlaylistTracks = decoded.items.compactMap { $0.track }
                    } else {
                        self.currentPlaylistTracks.append(contentsOf: decoded.items.compactMap { $0.track })
                    }
                    self.tracksError = nil
                }
            }
        } catch {
            await MainActor.run {
                self.tracksError = "Error: \(error.localizedDescription)"
            }
        }
    }

    func loadMoreTracks() async {
        guard let nextURL = nextTracksURL,
              let token = accessToken,
              let playlistId = currentPlaylistId else { return }

        var request = URLRequest(url: URL(string: nextURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            if playlistId == "liked_songs" {
                let decoded = try JSONDecoder().decode(LikedTracksResponse.self, from: data)
                nextTracksURL = decoded.next
                DispatchQueue.main.async {
                    self.currentPlaylistTracks.append(contentsOf: decoded.items.map { $0.track })
                }
            } else {
                let decoded = try JSONDecoder().decode(PlaylistTracksResponse.self, from: data)
                nextTracksURL = decoded.next
                DispatchQueue.main.async {
                    self.currentPlaylistTracks.append(contentsOf: decoded.items.compactMap { $0.track })
                }
            }
        } catch {
            print("Failed to load more tracks: \(error)")
        }
    }

    func playTrack(uri: String, contextUri: String? = nil, offset: Int? = nil) async {
        var body: [String: Any] = [:]

        if let context = contextUri, let trackOffset = offset {
            // Play from context (playlist) at specific position
            body["context_uri"] = context
            body["offset"] = ["position": trackOffset]
        } else {
            // Play single track
            body["uris"] = [uri]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
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

    func toggleShuffle() async {
        guard let token = accessToken else { return }

        let newState = !isShuffleOn
        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/shuffle?state=\(newState)")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            _ = try await URLSession.shared.data(for: request)
            DispatchQueue.main.async {
                self.isShuffleOn = newState
            }
        } catch {
            print("Failed to toggle shuffle: \(error)")
        }
    }

    func fetchShuffleState() async {
        // Get from current playback
        if let playback = currentPlayback {
            DispatchQueue.main.async {
                self.isShuffleOn = playback.shuffleState ?? false
            }
        }
    }
}
