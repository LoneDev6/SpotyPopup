import AppKit
import SwiftUI

class MenuBarController: NSObject {
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
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
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
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        mainWindow = window
    }
}

import Combine
