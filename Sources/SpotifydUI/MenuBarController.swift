import AppKit
import SwiftUI
import MediaPlayer

class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let api = SpotifyAPI()
    private let auth = SpotifyAuth()
    private var timer: Timer?
    private var isPopoverOpen = false

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

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "SpotifydUI")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.delegate = self
    }

    private func refreshPopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: MenuView(
                api: api,
                auth: auth,
                onOpenMainWindow: {},
                onClose: { [weak self] in
                    self?.closePopover()
                }
            )
        )
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
        popover.performClose(nil)
        isPopoverOpen = false
        stopPolling()
        popover.contentViewController = nil
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        isPopoverOpen = false
        stopPolling()
    }

    private func startPolling() {
        stopPolling()
        // Poll every 10 seconds to avoid rate limiting
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
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
