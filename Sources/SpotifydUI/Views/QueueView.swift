import SwiftUI

struct QueueView: View {
    let queue: [Track]
    let currentTrack: Track?
    let onClose: () -> Void
    let onPlay: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Queue")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if let current = currentTrack {
                Text("Now Playing")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                QueueTrackRow(track: current, isPlaying: true, onPlay: {})
                    .padding(.bottom, 16)

                if !queue.isEmpty {
                    Text("Next in Queue")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(queue) { track in
                        QueueTrackRow(
                            track: track,
                            isPlaying: false,
                            onPlay: { onPlay(track) }
                        )
                    }
                }
            }

            if queue.isEmpty && currentTrack == nil {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Queue is empty")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }
}

struct QueueTrackRow: View {
    let track: Track
    let isPlaying: Bool
    let onPlay: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            if let artURL = track.albumArtURL, let url = URL(string: artURL) {
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
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(track.name)
                        .font(.system(size: 14, weight: isPlaying ? .semibold : .regular))
                        .lineLimit(1)

                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                }

                Text(track.artistNames)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering && !isPlaying {
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isPlaying ? Color.accentColor.opacity(0.1) : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
