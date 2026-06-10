import SwiftUI

struct MainWindow: View {
    @ObservedObject var api: SpotifyAPI

    @State private var selectedPlaylist: Playlist?
    @State private var showQueue = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 0) {
                    // Sidebar - Playlists
                    PlaylistSidebar(
                        playlists: api.playlists,
                        selectedPlaylist: $selectedPlaylist,
                        onSelectPlaylist: { playlist in
                            selectedPlaylist = playlist
                            // Clear current tracks immediately
                            api.currentPlaylistTracks = []
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
                            onClose: { showQueue = false }
                        )
                    } else {
                        TrackListView(
                            tracks: api.currentPlaylistTracks,
                            playlistName: selectedPlaylist?.name ?? "Select a playlist",
                            playlistId: selectedPlaylist?.id,
                            isShuffleOn: api.isShuffleOn,
                            tracksError: api.tracksError,
                            onPlay: { track, index in
                                Task {
                                    if let playlist = selectedPlaylist, !playlist.isLikedSongs {
                                        // Play from playlist context at this position
                                        await api.playTrack(
                                            uri: "spotify:track:\(track.id)",
                                            contextUri: "spotify:playlist:\(playlist.id)",
                                            offset: index
                                        )
                                    } else {
                                        // Liked songs - play single track
                                        await api.playTrack(uri: "spotify:track:\(track.id)")
                                    }
                                }
                            },
                            onAddToQueue: { track in
                                Task {
                                    await api.addToQueue(uri: "spotify:track:\(track.id)")
                                }
                            },
                            onLoadMore: {
                                Task {
                                    await api.loadMoreTracks()
                                }
                            },
                            onToggleShuffle: {
                                Task {
                                    await api.toggleShuffle()
                                }
                            }
                        )
                    }
                }

                // Bottom player bar overlay
                VStack {
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
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            Task {
                await api.fetchPlaylists()
            }
        }
    }
}
