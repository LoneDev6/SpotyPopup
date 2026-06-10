import SwiftUI

struct MainWindow: View {
    @ObservedObject var api: SpotifyAPI

    @State private var selectedPlaylist: Playlist?
    @State private var showQueue = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar - Playlists
                PlaylistSidebar(
                    playlists: api.playlists,
                    selectedPlaylist: $selectedPlaylist,
                    onSelectPlaylist: { playlist in
                        selectedPlaylist = playlist
                        Task {
                            await api.fetchPlaylistTracks(playlistId: playlist.id)
                        }
                    }
                )
                .frame(width: 250)

                Divider()

                // Main content - Tracks
                if showQueue {
                    QueueView(
                        queue: api.queue,
                        currentTrack: api.currentPlayback?.item,
                        onClose: { showQueue = false },
                        onPlay: { track in
                            Task {
                                await api.playTrack(uri: "spotify:track:\(track.id)")
                            }
                        }
                    )
                } else {
                    TrackListView(
                        tracks: api.currentPlaylistTracks,
                        playlistName: selectedPlaylist?.name ?? "Select a playlist",
                        onPlay: { track in
                            Task {
                                await api.playTrack(uri: "spotify:track:\(track.id)")
                            }
                        },
                        onAddToQueue: { track in
                            Task {
                                await api.addToQueue(uri: "spotify:track:\(track.id)")
                            }
                        }
                    )
                }
            }

            // Bottom player bar
            VStack(spacing: 0) {
                Spacer()
                Divider()
                PlayerBar(
                    playback: api.currentPlayback,
                    onPlay: { Task { await api.play() } },
                    onPause: { Task { await api.pause() } },
                    onNext: { Task { await api.nextTrack() } },
                    onPrevious: { Task { await api.previousTrack() } },
                    onToggleQueue: {
                        showQueue.toggle()
                        if showQueue {
                            Task { await api.fetchQueue() }
                        }
                    }
                )
                .frame(height: 90)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            Task {
                await api.fetchPlaylists()
            }
        }
    }
}
