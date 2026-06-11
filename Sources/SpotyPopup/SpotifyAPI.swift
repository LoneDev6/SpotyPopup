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
    @Published var availableDevices: [Device] = []

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

    private func handleAuthError(statusCode: Int) async -> Bool {
        if statusCode == 401 || statusCode == 403 {
            AppLogger.info("Token error (\(statusCode)), attempting refresh...", category: AppLogger.auth)
            await authHandler?.refreshAccessToken()

            if let newToken = authHandler?.accessToken {
                self.accessToken = newToken
                return true
            }
        }
        return false
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
                await MainActor.run {
                    self.currentPlayback = nil
                }
                return
            }

            let playback = try JSONDecoder().decode(PlaybackState.self, from: data)
            await MainActor.run {
                self.currentPlayback = playback
            }
        } catch {
            AppLogger.error("Failed to fetch playback: \(error)", category: AppLogger.playback)
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
            AppLogger.error("Failed to send command \(endpoint): \(error)", category: AppLogger.api)
        }
    }

    func fetchPlaylists() async {
        guard let token = accessToken else {
            AppLogger.error("No token for fetchPlaylists", category: AppLogger.auth)
            DispatchQueue.main.async {
                self.lastError = "No access token - please login"
            }
            return
        }

        AppLogger.info("Fetching playlists...", category: AppLogger.api)

        var request = URLRequest(url: URL(string: "\(baseURL)/me/playlists?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.debug("Playlists response status: \(httpResponse.statusCode)", category: AppLogger.api)

                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    // Token expired or invalid - try to refresh
                    print("Token error (\(httpResponse.statusCode)), attempting refresh...")
                    await authHandler?.refreshAccessToken()

                    // Retry with new token if available
                    if let newToken = authHandler?.accessToken {
                        self.accessToken = newToken
                        await fetchPlaylists()
                    } else {
                        await MainActor.run {
                            self.lastError = "Authentication failed - please login again"
                        }
                    }
                    return
                }

                if httpResponse.statusCode != 200 {
                    let errorString = String(data: data, encoding: .utf8) ?? "No error details"
                    AppLogger.error("Playlists error: \(errorString)", category: AppLogger.api)
                    await MainActor.run {
                        self.lastError = "API Error \(httpResponse.statusCode): \(errorString)"
                    }
                    return
                }
            }

            let playlistResponse = try JSONDecoder().decode(PlaylistsResponse.self, from: data)
            AppLogger.debug("Decoded \(playlistResponse.items.count) playlists", category: AppLogger.api)

            // Create synthetic "Liked Songs" playlist
            let likedSongs = Playlist.createLikedSongsPlaylist()

            await MainActor.run {
                self.playlists = [likedSongs] + playlistResponse.items
                self.lastError = nil
                AppLogger.debug("Set \(self.playlists.count) playlists", category: AppLogger.api)
            }
        } catch {
            AppLogger.error("Playlist decode error: \(error)", category: AppLogger.api)
            await MainActor.run {
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
                if await handleAuthError(statusCode: httpResponse.statusCode) {
                    await fetchPlaylistTracks(playlistId: playlistId, reset: reset)
                    return
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    await MainActor.run {
                        self.tracksError = "Authentication failed - please login again"
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
                await MainActor.run {
                    self.currentPlaylistTracks.append(contentsOf: decoded.items.map { $0.track })
                }
            } else {
                let decoded = try JSONDecoder().decode(PlaylistTracksResponse.self, from: data)
                nextTracksURL = decoded.next
                await MainActor.run {
                    self.currentPlaylistTracks.append(contentsOf: decoded.items.compactMap { $0.track })
                }
            }
        } catch {
            AppLogger.error("Failed to load more tracks: \(error)", category: AppLogger.api)
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
            AppLogger.error("Failed to add to queue: \(error)", category: AppLogger.playback)
        }
    }

    func fetchQueue() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/queue")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(QueueResponse.self, from: data)
            await MainActor.run {
                self.queue = response.queue
            }
        } catch {
            AppLogger.error("Failed to fetch queue: \(error)", category: AppLogger.playback)
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
            await MainActor.run {
                self.isShuffleOn = newState
            }
        } catch {
            AppLogger.error("Failed to toggle shuffle: \(error)", category: AppLogger.playback)
        }
    }

    func fetchShuffleState() async {
        // Get from current playback
        if let playback = currentPlayback {
            await MainActor.run {
                self.isShuffleOn = playback.shuffleState ?? false
            }
        }
    }

    func setVolume(_ volume: Int) async {
        guard let token = accessToken else { return }

        let clampedVolume = max(0, min(100, volume))
        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/volume?volume_percent=\(clampedVolume)")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            AppLogger.error("Failed to set volume: \(error)", category: AppLogger.playback)
        }
    }

    func seekToPosition(_ positionMs: Int) async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/seek?position_ms=\(positionMs)")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            AppLogger.error("Failed to seek: \(error)", category: AppLogger.playback)
        }
    }

    func fetchAvailableDevices() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/devices")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DevicesResponse.self, from: data)
            await MainActor.run {
                self.availableDevices = response.devices
            }
        } catch {
            AppLogger.error("Failed to fetch devices: \(error)", category: AppLogger.api)
        }
    }

    func transferPlayback(to deviceId: String) async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_ids": [deviceId],
            "play": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await fetchCurrentPlayback()
        } catch {
            AppLogger.error("Failed to transfer playback: \(error)", category: AppLogger.playback)
        }
    }
}

struct Device: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case isActive = "is_active"
    }
}

struct DevicesResponse: Codable {
    let devices: [Device]
}
