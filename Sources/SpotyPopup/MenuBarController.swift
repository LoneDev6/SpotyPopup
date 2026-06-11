import AppKit
import MediaPlayer
import Combine

class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let api = SpotifyAPI()
    private let auth = SpotifyAuth()
    private var timer: Timer?
    private var isPopoverOpen = false
    private var statusBarView: StatusBarView?

    override init() {
        super.init()
        setupMenuBar()
        setupPopover()
        setupRemoteCommands()

        // Link auth and API
        api.setAuthHandler(auth)

        auth.loadToken()

        if let token = auth.accessToken {
            api.setAccessToken(token)
        }

        auth.$accessToken
            .compactMap { $0 }
            .sink { [weak self] token in
                self?.api.setAccessToken(token)
                self?.transferToLocalDevice()
            }
            .store(in: &cancellables)
    }

    private func transferToLocalDevice() {
        Task {
            await api.fetchAvailableDevices()

            // Find local device (spotifyd or computer)
            if let localDevice = api.availableDevices.first(where: {
                $0.name.lowercased().contains("spotifyd") || $0.type.lowercased() == "computer"
            }), !localDevice.isActive {
                await api.transferPlayback(to: localDevice.id)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var imageCache = [String: NSImage]()
    private var currentTrackId: String?

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create custom view and set as button's superview
        if let button = statusItem.button {
            let customView = StatusBarView(frame: button.bounds)
            customView.onClick = { [weak self] in
                self?.togglePopover()
            }
            statusBarView = customView

            // Keep button action for proper popover behavior
            button.action = #selector(togglePopover)
            button.target = self
            button.title = ""
            button.image = nil

            // Add custom view
            button.addSubview(customView)
        }

        updateStatusItemView()

        // Observe playback changes to update menu bar
        api.$currentPlayback
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemView()
            }
            .store(in: &cancellables)

        // Start background polling for status bar even when popover closed
        startPolling()
    }

    private func updateStatusItemView() {
        guard let view = statusBarView else { return }

        if let playback = api.currentPlayback, let track = playback.item {
            let trackText = "\(track.name) - \(track.artistNames)"
            let trackId = track.id

            // Only fetch/update image if track changed
            if currentTrackId != trackId {
                currentTrackId = trackId

                if let artURL = track.albumArtURL, let url = URL(string: artURL) {
                    // Check cache first
                    if let cached = imageCache[artURL] {
                        view.update(image: cached, text: trackText)
                    } else {
                        // Load and cache - download only on track change
                        loadImage(from: url) { [weak self] image in
                            DispatchQueue.main.async {
                                let resized = image?.resized(to: NSSize(width: 16, height: 16))
                                if let resized = resized {
                                    self?.imageCache[artURL] = resized
                                }
                                view.update(image: resized, text: trackText)
                            }
                        }
                    }
                } else {
                    let icon = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
                    view.update(image: icon, text: trackText)
                }
            }
            // Same track = no update call, StatusBarView keeps existing image & text
        } else {
            currentTrackId = nil
            let icon = NSImage(systemSymbolName: "music.note", accessibilityDescription: "SpotyPopup")
            view.update(image: icon, text: "No Song")
        }
    }

    private func loadImage(from url: URL, completion: @escaping (NSImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.delegate = self
    }

    private func refreshPopoverContent() {
        let menuView = MenuView(
            api: api,
            auth: auth,
            onClose: {
                NSApplication.shared.terminate(nil)
            }
        )
        let viewController = NSViewController()
        viewController.view = menuView
        popover.contentViewController = viewController
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if isPopoverOpen {
                closePopover()
            } else {
                openPopover(relativeTo: button)
            }
        }
    }

    private func openPopover(relativeTo button: NSButton) {
        refreshPopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverOpen = true
        startPolling()
        Task {
            await api.fetchCurrentPlayback()
        }
    }

    private func closePopover() {
        isPopoverOpen = false
        popover.contentViewController = nil  // Destroy SwiftUI view FIRST
        popover.performClose(nil)
        startPolling() // Resume background polling at slower rate
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        isPopoverOpen = false
        popover.contentViewController = nil  // Ensure cleanup
        startPolling() // Resume background polling at slower rate
    }

    private var lastPollingInterval: TimeInterval = 0

    private func startPolling() {
        // Calculate desired interval
        let interval: TimeInterval = {
            if isPopoverOpen {
                return 2.0
            } else if api.currentPlayback?.isPlaying == true {
                return 3.0
            } else {
                return 10.0
            }
        }()

        // Only restart if interval changed
        if timer != nil && interval == lastPollingInterval {
            return
        }

        stopPolling()
        lastPollingInterval = interval

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.api.fetchCurrentPlayback()
                self?.updateNowPlayingInfo()
            }
        }
        timer?.fire()
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func updateNowPlayingInfo() {
        guard let playback = api.currentPlayback,
              let track = playback.item else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artistNames

        if let durationMs = track.durationMs {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(playback.progressMs) / 1000.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playback.isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func handleAuthCallback(url: URL) {
        auth.handleCallback(url: url)
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task {
                await self?.api.play()
            }
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task {
                await self?.api.pause()
            }
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task {
                if self?.api.currentPlayback?.isPlaying == true {
                    await self?.api.pause()
                } else {
                    await self?.api.play()
                }
            }
            return .success
        }

        // Next track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task {
                await self?.api.nextTrack()
            }
            return .success
        }

        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task {
                await self?.api.previousTrack()
            }
            return .success
        }
    }
}

import Combine

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
