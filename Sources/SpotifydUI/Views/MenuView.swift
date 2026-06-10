import SwiftUI

struct MenuView: View {
    @ObservedObject var api: SpotifyAPI
    @ObservedObject var auth: SpotifyAuth

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isAuthenticated {
                loginView
            } else if let playback = api.currentPlayback, let track = playback.item {
                playbackView(track: track, isPlaying: playback.isPlaying)
            } else {
                noPlaybackView
            }
        }
        .frame(width: 280)
    }

    private var loginView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Not authenticated")
                .font(.headline)

            Button("Login with Spotify") {
                auth.authenticate()
            }
            .buttonStyle(.borderedProminent)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func playbackView(track: Track, isPlaying: Bool) -> some View {
        VStack(spacing: 12) {
            if let artURL = track.albumArtURL, let url = URL(string: artURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 200, height: 200)
                .cornerRadius(8)
            }

            VStack(spacing: 4) {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(track.artistNames)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                Button(action: {
                    Task {
                        await api.previousTrack()
                    }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        if isPlaying {
                            await api.pause()
                        } else {
                            await api.play()
                        }
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        await api.nextTrack()
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 8)
        }
        .padding()
    }

    private var noPlaybackView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No active playback")
                .font(.headline)

            Text("Start playing on Spotify")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Refresh") {
                Task {
                    await api.fetchCurrentPlayback()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
