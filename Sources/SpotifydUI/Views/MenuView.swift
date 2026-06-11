import SwiftUI

struct MenuView: View {
    @ObservedObject var api: SpotifyAPI
    @ObservedObject var auth: SpotifyAuth
    var onOpenMainWindow: () -> Void
    var onClose: () -> Void

    @State private var showQueue = false
    @State private var showVolumeControl = false
    @State private var volume: Double = 50
    @State private var showDevices = false
    @State private var localProgressMs: Int = 0
    @State private var lastSyncTime: Date = Date()
    @State private var progressTimer: Timer?
    @State private var isManualSeek = false

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isAuthenticated {
                loginView
            } else if showDevices {
                devicesView
            } else if showQueue {
                queueView
            } else if let playback = api.currentPlayback, let track = playback.item {
                playbackView(track: track, playback: playback)
            } else {
                noPlaybackView
            }

            if auth.isAuthenticated && !showQueue && !showDevices {
                headerBar
            }
        }
        .frame(width: 320, height: 480)
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                showDevices.toggle()
                if showDevices {
                    Task { await api.fetchAvailableDevices() }
                }
            }) {
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("Switch device")

            Button(action: {
                showQueue.toggle()
                if showQueue {
                    Task { await api.fetchQueue() }
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("Show queue")

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    showVolumeControl.toggle()
                }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Volume")

                if showVolumeControl {
                    Slider(value: $volume, in: 0...100)
                        .frame(width: 80)
                        .onChange(of: volume) { newValue in
                            Task {
                                await api.setVolume(Int(newValue))
                            }
                        }
                }
            }

            Button(action: {
                auth.logout()
            }) {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Logout")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
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
        .frame(maxHeight: .infinity)
    }

    private func playbackView(track: Track, playback: PlaybackState) -> some View {
        VStack(spacing: 0) {
            // Album art and track info
            VStack(spacing: 12) {
                if let artURL = track.albumArtURL, let url = URL(string: artURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 240, height: 240)
                    .cornerRadius(8)
                }

                VStack(spacing: 4) {
                    Text(track.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(track.artistNames)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 12)

            Spacer()

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    let progressValue = currentProgress(playback: playback, duration: track.durationMs ?? 0)

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)

                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * progressValue, height: 4)
                    }
                    .cornerRadius(2)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard let duration = track.durationMs else { return }
                                let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                let newPositionMs = Int(Double(duration) * newProgress)
                                localProgressMs = newPositionMs
                                isManualSeek = true
                                Task {
                                    await api.seekToPosition(newPositionMs)
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    isManualSeek = false
                                }
                            }
                    )
                }
                .frame(height: 4)
                .padding(.horizontal, 20)

                HStack {
                    Text(formatTime(localProgressMs))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatTime(track.durationMs))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                startProgressTimer(playback: playback)
            }
            .onDisappear {
                stopProgressTimer()
            }
            .onChange(of: playback.progressMs) { newProgress in
                syncProgress(playback: playback)
            }
            .onChange(of: track.id) { _ in
                syncProgress(playback: playback)
                startProgressTimer(playback: playback)
            }

            // Playback controls
            HStack(spacing: 24) {
                Button(action: {
                    stopProgressTimer()
                    localProgressMs = 0
                    Task {
                        await api.previousTrack()
                    }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        if playback.isPlaying {
                            await api.pause()
                        } else {
                            await api.play()
                        }
                    }
                }) {
                    Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                }
                .buttonStyle(.plain)

                Button(action: {
                    stopProgressTimer()
                    localProgressMs = 0
                    Task {
                        await api.nextTrack()
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 16)
            .padding(.bottom, 8)
        }
    }

    private var devicesView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Devices")
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button(action: {
                    Task { await api.fetchAvailableDevices() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            if api.availableDevices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hifispeaker")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No devices found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Refresh") {
                        Task { await api.fetchAvailableDevices() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(api.availableDevices) { device in
                            Button(action: {
                                Task {
                                    await api.transferPlayback(to: device.id)
                                    showDevices = false
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: deviceIcon(for: device.type))
                                        .font(.system(size: 24))
                                        .foregroundColor(device.isActive ? .green : .secondary)
                                        .frame(width: 40)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name)
                                            .font(.system(size: 14, weight: device.isActive ? .semibold : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(device.type.capitalized)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if device.isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }
                    }
                }
            }

            // Bottom back button
            HStack {
                Button(action: {
                    showDevices = false
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private var queueView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Queue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            if api.queue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Queue is empty")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(api.queue) { track in
                            HStack(spacing: 8) {
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

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.name)
                                        .font(.system(size: 13))
                                        .lineLimit(1)

                                    Text(track.artistNames)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                            Divider()
                        }
                    }
                }
            }

            // Bottom back button
            HStack {
                Button(action: {
                    showQueue = false
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
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
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private func currentProgress(playback: PlaybackState, duration: Int) -> Double {
        guard duration > 0 else { return 0 }
        let currentMs = localProgressMs
        return min(1.0, Double(currentMs) / Double(duration))
    }

    private func syncProgress(playback: PlaybackState) {
        guard !isManualSeek else { return }
        localProgressMs = playback.progressMs
        lastSyncTime = Date()
    }

    private func startProgressTimer(playback: PlaybackState) {
        stopProgressTimer()
        syncProgress(playback: playback)

        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            guard let pb = api.currentPlayback, pb.isPlaying else { return }

            // Increment local progress
            localProgressMs += 1000

            // Clamp to duration
            if let duration = pb.item?.durationMs, localProgressMs > duration {
                localProgressMs = duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func formatTime(_ ms: Int?) -> String {
        guard let ms = ms else { return "--:--" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var volumeIcon: String {
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 33 {
            return "speaker.wave.1.fill"
        } else if volume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func deviceIcon(for type: String) -> String {
        switch type.lowercased() {
        case "computer":
            return "laptopcomputer"
        case "smartphone":
            return "iphone"
        case "speaker":
            return "hifispeaker.fill"
        case "tv":
            return "tv"
        case "avr":
            return "amplifier"
        case "stb":
            return "appletv"
        case "audio_dongle":
            return "cable.connector"
        case "game_console":
            return "gamecontroller"
        case "cast_video":
            return "airplayvideo"
        case "cast_audio":
            return "airplayaudio"
        case "automobile":
            return "car"
        default:
            return "music.note"
        }
    }
}
