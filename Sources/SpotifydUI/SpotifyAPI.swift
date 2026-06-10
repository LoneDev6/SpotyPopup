import Foundation

class SpotifyAPI: ObservableObject {
    @Published var currentPlayback: PlaybackState?
    @Published var isLoading = false

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

    private func sendPlayerCommand(endpoint: String, method: String) async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/me/player/\(endpoint)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            _ = try await URLSession.shared.data(for: request)
            await fetchCurrentPlayback()
        } catch {
            print("Failed to send command \(endpoint): \(error)")
        }
    }
}
