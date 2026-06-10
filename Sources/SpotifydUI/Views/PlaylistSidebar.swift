import SwiftUI

struct PlaylistSidebar: View {
    let playlists: [Playlist]
    @Binding var selectedPlaylist: Playlist?
    let onSelectPlaylist: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your Playlists (\(playlists.count))")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if playlists.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Text("Loading playlists...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(playlists) { playlist in
                            PlaylistRow(
                                playlist: playlist,
                                isSelected: selectedPlaylist?.id == playlist.id
                            )
                            .onTapGesture {
                                onSelectPlaylist(playlist)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct PlaylistRow: View {
    let playlist: Playlist
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if playlist.isLikedSongs {
                // Special icon for Liked Songs
                ZStack {
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 48, height: 48)
                    .cornerRadius(4)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            } else if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 48, height: 48)
                .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .cornerRadius(4)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Text("\(playlist.tracks.total) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}
