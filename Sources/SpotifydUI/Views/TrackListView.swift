import SwiftUI

struct TrackListView: View {
    let tracks: [Track]
    let playlistName: String
    let playlistId: String?
    let isShuffleOn: Bool
    let tracksError: String?
    let onPlay: (Track, Int) -> Void
    let onAddToQueue: (Track) -> Void
    let onLoadMore: () -> Void
    let onToggleShuffle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlistName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Tracks loaded: \(tracks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onToggleShuffle) {
                    Image(systemName: isShuffleOn ? "shuffle.circle.fill" : "shuffle")
                        .font(.system(size: 24))
                        .foregroundColor(isShuffleOn ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isShuffleOn ? "Shuffle on" : "Shuffle off")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if let error = tracksError {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error loading tracks")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else if tracks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Loading tracks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(
                                track: track,
                                index: index + 1,
                                onPlay: { onPlay(track, index) },
                                onAddToQueue: { onAddToQueue(track) }
                            )
                            .onAppear {
                                if index == tracks.count - 10 {
                                    onLoadMore()
                                }
                            }
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
}

struct TrackRow: View {
    let track: Track
    let index: Int
    let onPlay: () -> Void
    let onAddToQueue: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Index or play button
            ZStack {
                if isHovering {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(index)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
            .frame(width: 40)

            // Album art with overlay play button
            ZStack {
                if let artURL = track.albumArtURL, let url = URL(string: artURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                }

                if isHovering {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 40, height: 40)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.system(size: 14))
                    .lineLimit(1)

                Text(track.artistNames)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Album name
            Text(track.album.name)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)

            // Duration
            Text(track.durationFormatted)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)

            // Add to queue button
            if isHovering {
                Button(action: onAddToQueue) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Add to queue")
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onPlay()
        }
    }
}
