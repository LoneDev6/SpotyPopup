import Foundation
import AppKit
import CryptoKit

class SpotifyAuth: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?

    private let clientID = SpotifyConfig.clientID
    private let redirectURI = SpotifyConfig.redirectURI
    private let scope = "user-read-playback-state user-modify-playback-state playlist-read-private playlist-read-collaborative user-library-read playlist-modify-public playlist-modify-private"

    private var codeVerifier: String?
    private var codeChallenge: String?
    private var refreshToken: String?
    private var tokenExpiresAt: Date?

    func authenticate() {
        generatePKCECodes()
        let authURL = buildAuthURL()
        NSWorkspace.shared.open(authURL)
    }

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        exchangeCodeForToken(code: code)
    }

    private func generatePKCECodes() {
        // Generate random code verifier (43-128 chars)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let base64 = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        codeVerifier = String(base64.prefix(128))

        // Generate code challenge (SHA256 of verifier)
        guard let verifier = codeVerifier,
              let data = verifier.data(using: .utf8) else {
            return
        }

        let hash = SHA256.hash(data: data)
        codeChallenge = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func buildAuthURL() -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        guard let url = components.url else {
            fatalError("Failed to build authorization URL")
        }
        return url
    }

    private func exchangeCodeForToken(code: String) {
        guard let verifier = codeVerifier else {
            AppLogger.error("Missing code verifier", category: AppLogger.auth)
            return
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data else {
                if let error = error {
                    AppLogger.error("Token exchange error: \(error)", category: AppLogger.auth)
                }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let token = json["access_token"] as? String {
                    let refresh = json["refresh_token"] as? String
                    let expiresIn = json["expires_in"] as? Int ?? 3600

                    DispatchQueue.main.async {
                        self?.accessToken = token
                        self?.refreshToken = refresh
                        self?.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
                        self?.isAuthenticated = true
                        self?.saveTokens(accessToken: token, refreshToken: refresh, expiresAt: self?.tokenExpiresAt)
                    }
                } else {
                    AppLogger.error("Token exchange failed: \(json)", category: AppLogger.auth)
                }
            }
        }.resume()
    }

    private func saveTokens(accessToken: String, refreshToken: String?, expiresAt: Date?) {
        UserDefaults.standard.set(accessToken, forKey: "spotify_access_token")
        if let refresh = refreshToken {
            UserDefaults.standard.set(refresh, forKey: "spotify_refresh_token")
        }
        if let expires = expiresAt {
            UserDefaults.standard.set(expires, forKey: "spotify_token_expires_at")
        }
    }

    func loadToken() {
        if let token = UserDefaults.standard.string(forKey: "spotify_access_token") {
            accessToken = token
            refreshToken = UserDefaults.standard.string(forKey: "spotify_refresh_token")
            tokenExpiresAt = UserDefaults.standard.object(forKey: "spotify_token_expires_at") as? Date
            isAuthenticated = true

            // Check if token is expired or about to expire (within 5 minutes)
            if let expiresAt = tokenExpiresAt, Date().addingTimeInterval(300) > expiresAt {
                Task {
                    await refreshAccessToken()
                }
            }
        }
    }

    func refreshAccessToken() async {
        guard let refresh = refreshToken else {
            AppLogger.error("No refresh token available", category: AppLogger.auth)
            return
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": clientID
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                let expiresIn = json["expires_in"] as? Int ?? 3600

                await MainActor.run {
                    self.accessToken = token
                    self.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
                    self.saveTokens(accessToken: token, refreshToken: refresh, expiresAt: self.tokenExpiresAt)
                }
            } else {
                AppLogger.error("Token refresh failed, need to re-authenticate", category: AppLogger.auth)
                await MainActor.run {
                    self.logout()
                }
            }
        } catch {
            AppLogger.error("Token refresh error: \(error)", category: AppLogger.auth)
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "spotify_access_token")
        UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
        UserDefaults.standard.removeObject(forKey: "spotify_token_expires_at")
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = nil
        isAuthenticated = false
    }
}

