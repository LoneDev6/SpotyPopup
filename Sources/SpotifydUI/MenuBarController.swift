import AppKit
import SwiftUI

class MenuBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let api = SpotifyAPI()
    private let auth = SpotifyAuth()
    private var timer: Timer?
    private var mainWindow: NSWindow?

    override init() {
        super.init()
        setupMenuBar()
        setupPopover()
        setupMediaKeys()

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
                self?.startPolling()
            }
            .store(in: &cancellables)
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
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuView(
                api: api,
                auth: auth,
                onOpenMainWindow: { [weak self] in
                    self?.openMainWindow()
                    self?.popover.performClose(nil)
                },
                onClose: { [weak self] in
                    self?.popover.performClose(nil)
                }
            )
        )
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                Task {
                    await api.fetchCurrentPlayback()
                }
            }
        }
    }

    private func startPolling() {
        timer?.invalidate()
        // Poll every 10 seconds to avoid rate limiting
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.api.fetchCurrentPlayback()
            }
        }
        timer?.fire()
    }

    func handleAuthCallback(url: URL) {
        auth.handleCallback(url: url)
    }

    private func openMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MainWindow(api: api)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SpotifydUI"
        window.setContentSize(NSSize(width: 1000, height: 700))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        mainWindow = window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        mainWindow = nil
    }

    private func setupMediaKeys() {
        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return event }

            let keyCode = (event.data1 & 0xFFFF0000) >> 16
            let keyFlags = event.data1 & 0x0000FFFF
            let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA

            if keyPressed {
                switch keyCode {
                case 16: // Play/Pause
                    Task { [weak self] in
                        if self?.api.currentPlayback?.isPlaying == true {
                            await self?.api.pause()
                        } else {
                            await self?.api.play()
                        }
                    }
                    return nil
                case 17: // Next
                    Task { [weak self] in
                        await self?.api.nextTrack()
                    }
                    return nil
                case 18: // Previous
                    Task { [weak self] in
                        await self?.api.previousTrack()
                    }
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }
}

import Combine
