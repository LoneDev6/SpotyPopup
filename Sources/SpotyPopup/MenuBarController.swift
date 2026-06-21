import AppKit
import MediaPlayer
import Combine
import ApplicationServices

class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let api = SpotifyAPI()
    private let auth = SpotifyAuth()
    private var timer: Timer?
    private var isPopoverOpen = false
    private var statusBarView: StatusBarView?
    private var eventMonitor: Any?
    private var positionUpdateTimer: Timer?

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
            await api.prepareDeviceForPlay()
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
            customView.onRightClick = { [weak self] event in
                self?.showStatusMenu(with: event)
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

    private func showStatusMenu(with event: NSEvent) {
        guard let statusBarView else { return }

        let menu = NSMenu()
        let logoutItem = NSMenuItem(title: "Logout", action: #selector(logoutFromStatusMenu), keyEquivalent: "")
        logoutItem.target = self
        logoutItem.isEnabled = auth.isAuthenticated
        menu.addItem(logoutItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SpotyPopup", action: #selector(quitFromStatusMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        if isPopoverOpen {
            closePopover()
        }

        NSMenu.popUpContextMenu(menu, with: event, for: statusBarView)
    }

    @objc private func logoutFromStatusMenu() {
        auth.logout()
        if isPopoverOpen {
            closePopover()
        }
    }

    @objc private func quitFromStatusMenu() {
        NSApplication.shared.terminate(nil)
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
        popover.animates = true
        popover.delegate = self
    }

    private func refreshPopoverContent() {
        let menuView = MenuView(
            api: api,
            auth: auth
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
        print("🔍 openPopover called")
        refreshPopoverContent()
        print("🔍 Showing popover")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        isPopoverOpen = true
        print("🔍 Starting polling")
        startPolling()
        print("🔍 Starting event monitor")
        startEventMonitor()
        print("🔍 Starting position update timer")
        startPositionUpdateTimer()
        print("🔍 Fetching playback")
        Task {
            await api.fetchCurrentPlayback()
        }
    }

    private func closePopover() {
        isPopoverOpen = false
        stopEventMonitor()
        stopPositionUpdateTimer()
        popover.contentViewController = nil
        popover.performClose(nil)
        startPolling() // Resume background polling at slower rate
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        isPopoverOpen = false
        stopEventMonitor()
        stopPositionUpdateTimer()
        popover.contentViewController = nil
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

    // MARK: - Event Monitor

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if self?.isPopoverOpen == true {
                self?.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Fullscreen Detection

    private func isFrontmostAppFullscreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // Get all windows
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // Find frontmost app window
        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == app.processIdentifier,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let windowLayer = windowInfo[kCGWindowLayer as String] as? Int32,
                  windowLayer == 0 else {
                continue
            }

            let y = boundsDict["Y"] ?? 0
            let width = boundsDict["Width"] ?? 0
            let height = boundsDict["Height"] ?? 0

            // Check if window covers most of screen (allowing for menu bar)
            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let isFullWidth = width >= screenFrame.width - 10
                let isFullHeight = height >= screenFrame.height - 50
                let isAtTop = y <= 50

                if isFullWidth && isFullHeight && isAtTop {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Position Update

    private func startPositionUpdateTimer() {
        print("🔍 startPositionUpdateTimer called")
        positionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updatePopoverPosition()
        }
        print("🔍 Timer started: \(positionUpdateTimer != nil)")
    }

    private func stopPositionUpdateTimer() {
        positionUpdateTimer?.invalidate()
        positionUpdateTimer = nil
    }

    private func updatePopoverPosition() {
        print("🔍 updatePopoverPosition called")

        guard isPopoverOpen else {
            print("🔍 Popover not open")
            return
        }

        guard let button = statusItem.button else {
            print("🔍 No button")
            return
        }

        guard let window = button.window else {
            print("🔍 No window")
            return
        }

        guard let popoverWindow = popover.contentViewController?.view.window else {
            print("🔍 No popover window")
            return
        }

        print("🔍 All guards passed, checking fullscreen")
        let isFrontAppFullscreen = isFrontmostAppFullscreen()

        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonScreenFrame = window.convertToScreen(buttonFrame)

        // Add offset when frontmost app is fullscreen
        let yOffset: CGFloat = isFrontAppFullscreen ? 30 : 0
        let targetY = buttonScreenFrame.minY - popoverWindow.frame.height - yOffset

        // Only update if position changed significantly
        if abs(popoverWindow.frame.origin.y - targetY) > 2 {
            var frame = popoverWindow.frame
            frame.origin.y = targetY
            popoverWindow.setFrame(frame, display: false, animate: true)
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
