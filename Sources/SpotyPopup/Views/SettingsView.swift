import AppKit

final class SettingsView: NSView {
    private let backgroundEffectView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "Settings")

    private let spotifydSectionView = NSView()
    private let spotifydTitleLabel = NSTextField(labelWithString: "spotifyd")
    private let statusLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton()
    private let uninstallButton = NSButton()
    private let progressIndicator = NSProgressIndicator()

    private let webkitSectionView = NSView()
    private let webkitTitleLabel = NSTextField(labelWithString: "WebKit memory")
    private let instantMemoryButton = NSButton(radioButtonWithTitle: "Instant", target: nil, action: nil)
    private let delayedMemoryButton = NSButton(radioButtonWithTitle: "After 30 seconds of no usage", target: nil, action: nil)
    private let neverMemoryButton = NSButton(radioButtonWithTitle: "Never", target: nil, action: nil)

    private let accountSectionView = NSView()
    private let accountTitleLabel = NSTextField(labelWithString: "Account")
    private let logoutButton = NSButton()
    private let madeByButton = NSButton()
    private let donateButton = NSButton()

    private let onLogout: (() -> Void)?

    init(frame: NSRect, onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
        super.init(frame: frame)
        setupViews()
        refreshState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        backgroundEffectView.material = .hudWindow
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)

        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.alignment = .center
        addSubview(titleLabel)

        configureSectionView(spotifydSectionView)
        addSubview(spotifydSectionView)

        configureSectionTitle(spotifydTitleLabel)
        spotifydSectionView.addSubview(spotifydTitleLabel)

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .left
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.maximumNumberOfLines = 2
        spotifydSectionView.addSubview(statusLabel)

        installButton.title = "Install spotifyd"
        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(installButtonTapped)
        spotifydSectionView.addSubview(installButton)

        uninstallButton.title = "Uninstall spotifyd"
        uninstallButton.bezelStyle = .rounded
        uninstallButton.target = self
        uninstallButton.action = #selector(uninstallButtonTapped)
        spotifydSectionView.addSubview(uninstallButton)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        spotifydSectionView.addSubview(progressIndicator)

        configureSectionView(webkitSectionView)
        addSubview(webkitSectionView)

        configureSectionTitle(webkitTitleLabel)
        webkitSectionView.addSubview(webkitTitleLabel)

        for button in [instantMemoryButton, delayedMemoryButton, neverMemoryButton] {
            button.target = self
            button.action = #selector(memoryPolicyChanged)
            button.font = NSFont.systemFont(ofSize: 13)
            webkitSectionView.addSubview(button)
        }
        updateMemoryPolicyButtons()

        configureSectionView(accountSectionView)
        addSubview(accountSectionView)

        configureSectionTitle(accountTitleLabel)
        accountSectionView.addSubview(accountTitleLabel)

        logoutButton.title = "Logout"
        logoutButton.bezelStyle = .rounded
        logoutButton.target = self
        logoutButton.action = #selector(logoutButtonTapped)
        logoutButton.isEnabled = onLogout != nil
        accountSectionView.addSubview(logoutButton)

        configureLinkButton(madeByButton, title: "Made by LoneDev", action: #selector(madeByButtonTapped))
        accountSectionView.addSubview(madeByButton)

        configureLinkButton(donateButton, title: "Donate", action: #selector(donateButtonTapped))
        accountSectionView.addSubview(donateButton)
    }

    override func layout() {
        super.layout()

        backgroundEffectView.frame = bounds

        let inset: CGFloat = 18
        let contentWidth = bounds.width - (inset * 2)
        let sectionWidth = contentWidth

        titleLabel.frame = NSRect(x: inset, y: bounds.height - 58, width: contentWidth, height: 28)

        spotifydSectionView.frame = NSRect(x: inset, y: bounds.height - 178, width: sectionWidth, height: 104)
        spotifydTitleLabel.frame = NSRect(x: 14, y: 76, width: sectionWidth - 28, height: 18)
        statusLabel.frame = NSRect(x: 14, y: 42, width: sectionWidth - 28, height: 30)
        installButton.frame = NSRect(x: 14, y: 12, width: sectionWidth - 28, height: 26)
        uninstallButton.frame = installButton.frame
        progressIndicator.frame = NSRect(x: sectionWidth - 34, y: 78, width: 16, height: 16)

        webkitSectionView.frame = NSRect(x: inset, y: bounds.height - 320, width: sectionWidth, height: 124)
        webkitTitleLabel.frame = NSRect(x: 14, y: 94, width: sectionWidth - 28, height: 18)
        instantMemoryButton.frame = NSRect(x: 14, y: 64, width: sectionWidth - 28, height: 22)
        delayedMemoryButton.frame = NSRect(x: 14, y: 38, width: sectionWidth - 28, height: 22)
        neverMemoryButton.frame = NSRect(x: 14, y: 12, width: sectionWidth - 28, height: 22)

        accountSectionView.frame = NSRect(x: inset, y: 28, width: sectionWidth, height: 116)
        accountTitleLabel.frame = NSRect(x: 14, y: 86, width: sectionWidth - 28, height: 18)
        logoutButton.frame = NSRect(x: 14, y: 50, width: sectionWidth - 28, height: 28)

        let linkWidth = (sectionWidth - 34) / 2
        madeByButton.frame = NSRect(x: 14, y: 20, width: linkWidth, height: 22)
        donateButton.frame = NSRect(x: madeByButton.frame.maxX + 6, y: 20, width: linkWidth, height: 22)
    }

    func refreshState() {
        switch SpotifydManager.installState() {
        case .notInstalled:
            statusLabel.stringValue = "Not installed"
            installButton.isHidden = false
            uninstallButton.isHidden = true
            installButton.isEnabled = true
        case .appManaged(let path):
            statusLabel.stringValue = "Installed by SpotyPopup\n\(path)"
            installButton.isHidden = true
            uninstallButton.isHidden = false
            uninstallButton.isEnabled = true
        case .homebrew(let path):
            statusLabel.stringValue = "Installed with Homebrew\n\(path)"
            installButton.isHidden = true
            uninstallButton.isHidden = false
            uninstallButton.isEnabled = true
        case .system(let path):
            statusLabel.stringValue = "Installed outside SpotyPopup\n\(path)"
            installButton.isHidden = true
            uninstallButton.isHidden = true
        }
    }

    private func setWorking(_ working: Bool, message: String) {
        installButton.isEnabled = false
        uninstallButton.isEnabled = false
        installButton.isHidden = true
        uninstallButton.isHidden = true
        statusLabel.stringValue = message

        if working {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }

    @objc private func installButtonTapped() {
        setWorking(true, message: "Installing spotifyd...")

        Task {
            do {
                _ = try await SpotifydManager.install()
                await MainActor.run {
                    progressIndicator.stopAnimation(nil)
                    refreshState()
                }
            } catch {
                await MainActor.run {
                    showError("Install failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func uninstallButtonTapped() {
        setWorking(true, message: "Uninstalling spotifyd...")

        Task {
            do {
                _ = try await SpotifydManager.uninstall()
                await MainActor.run {
                    progressIndicator.stopAnimation(nil)
                    refreshState()
                }
            } catch {
                await MainActor.run {
                    showError("Uninstall failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func memoryPolicyChanged(_ sender: NSButton) {
        if sender === instantMemoryButton {
            AppSettings.spotifyWebMemoryPolicy = .instant
        } else if sender === delayedMemoryButton {
            AppSettings.spotifyWebMemoryPolicy = .after30Seconds
        } else {
            AppSettings.spotifyWebMemoryPolicy = .never
        }

        updateMemoryPolicyButtons()
    }

    private func updateMemoryPolicyButtons() {
        let policy = AppSettings.spotifyWebMemoryPolicy
        instantMemoryButton.state = policy == .instant ? .on : .off
        delayedMemoryButton.state = policy == .after30Seconds ? .on : .off
        neverMemoryButton.state = policy == .never ? .on : .off
    }

    @objc private func logoutButtonTapped() {
        let alert = NSAlert()
        alert.messageText = "Logout from Spotify?"
        alert.informativeText = "You will need to log in again before using Spotify controls."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Logout")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            onLogout?()
        }
    }

    @objc private func madeByButtonTapped() {
        openURL("https://github.com/LoneDev6")
    }

    @objc private func donateButtonTapped() {
        openURL("https://donate.devs.beer")
    }

    private func showError(_ message: String) {
        progressIndicator.stopAnimation(nil)
        statusLabel.stringValue = message
        refreshButtons()
    }

    private func refreshButtons() {
        switch SpotifydManager.installState() {
        case .notInstalled:
            installButton.isHidden = false
            uninstallButton.isHidden = true
            installButton.isEnabled = true
        case .appManaged, .homebrew:
            installButton.isHidden = true
            uninstallButton.isHidden = false
            uninstallButton.isEnabled = true
        case .system:
            installButton.isHidden = true
            uninstallButton.isHidden = true
        }
    }

    private func configureSectionView(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.14).cgColor
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        view.layer?.borderWidth = 1
    }

    private func configureSectionTitle(_ label: NSTextField) {
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
    }

    private func configureLinkButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = action
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.systemFont(ofSize: 12)
            ]
        )
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
