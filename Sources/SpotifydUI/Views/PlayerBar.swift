import SwiftUI

struct PlayerBar: View {
    let playback: PlaybackState?
    let onPlay: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onToggleQueue: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Left - Current track info
            HStack(spacing: 12) {
                if let track = playback?.item {
                    if let artURL = track.albumArtURL, let url = URL(string: artURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 56, height: 56)
                        .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)

                        Text(track.artistNames)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 200, alignment: .leading)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 56, height: 56)

                    Text("No track playing")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 200, alignment: .leading)
                }
            }
            .frame(width: 300)

            Spacer()

            // Center - Playback controls
            HStack(spacing: 16) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)

                Button(action: {
                    if playback?.isPlaying == true {
                        onPause()
                    } else {
                        onPlay()
                    }
                }) {
                    Image(systemName: playback?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right - Queue button
            Button(action: onToggleQueue) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .help("Show queue")
            .frame(width: 300, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
