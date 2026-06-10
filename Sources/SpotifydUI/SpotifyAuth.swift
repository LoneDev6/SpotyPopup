import Foundation
import AppKit
import CryptoKit

class SpotifyAuth: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?

    private let clientID = "65391d22d97c42f29120bd1614d06421"
    private let redirectURI = "spotifydui://callback"
    private let scope = "user-read-playback-state user-modify-playback-state playlist-read-private playlist-read-collaborative"

    private var codeVerifier: String?
    private var codeChallenge: String?

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
        codeVerifier = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(128)
            .description

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
        return components.url!
    }

    private func exchangeCodeForToken(code: String) {
        guard let verifier = codeVerifier else {
            print("Missing code verifier")
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
                    print("Token exchange error: \(error)")
                }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let token = json["access_token"] as? String {
                    DispatchQueue.main.async {
                        self?.accessToken = token
                        self?.isAuthenticated = true
                        self?.saveToken(token)
                    }
                } else {
                    print("Token exchange failed: \(json)")
                }
            }
        }.resume()
    }

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "spotify_access_token")
    }

    func loadToken() {
        if let token = UserDefaults.standard.string(forKey: "spotify_access_token") {
            accessToken = token
            isAuthenticated = true
        }
    }
}

