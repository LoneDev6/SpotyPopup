import AppKit

final class SettingsView: NSView {
    private let backgroundEffectView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "Settings")
    private let statusLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton()
    private let uninstallButton = NSButton()
    private let closeWebKitCheckbox = NSButton(checkboxWithTitle: "Close WebKit on Back", target: nil, action: nil)
    private let logoutButton = NSButton()
    private let madeByButton = NSButton()
    private let donateButton = NSButton()
    private let progressIndicator = NSProgressIndicator()
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

        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center
        addSubview(titleLabel)

        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        addSubview(statusLabel)

        installButton.title = "Install spotifyd"
        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(installButtonTapped)
        addSubview(installButton)

        uninstallButton.title = "Uninstall spotifyd"
        uninstallButton.bezelStyle = .rounded
        uninstallButton.target = self
        uninstallButton.action = #selector(uninstallButtonTapped)
        addSubview(uninstallButton)

        closeWebKitCheckbox.target = self
        closeWebKitCheckbox.action = #selector(closeWebKitCheckboxChanged)
        closeWebKitCheckbox.state = AppSettings.closeSpotifyWebViewOnBack ? .on : .off
        addSubview(closeWebKitCheckbox)

        logoutButton.title = "Logout"
        logoutButton.bezelStyle = .rounded
        logoutButton.target = self
        logoutButton.action = #selector(logoutButtonTapped)
        logoutButton.isEnabled = onLogout != nil
        addSubview(logoutButton)

        configureLinkButton(madeByButton, title: "Made by LoneDev", action: #selector(madeByButtonTapped))
        addSubview(madeByButton)

        configureLinkButton(donateButton, title: "Donate", action: #selector(donateButtonTapped))
        addSubview(donateButton)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        addSubview(progressIndicator)
    }

    override func layout() {
        super.layout()
        backgroundEffectView.frame = bounds
        titleLabel.frame = NSRect(x: 20, y: bounds.height - 56, width: bounds.width - 40, height: 24)
        statusLabel.frame = NSRect(x: 28, y: bounds.height - 150, width: bounds.width - 56, height: 56)
        installButton.frame = NSRect(x: 44, y: bounds.height - 220, width: bounds.width - 88, height: 32)
        uninstallButton.frame = NSRect(x: 44, y: bounds.height - 264, width: bounds.width - 88, height: 32)
        progressIndicator.frame = NSRect(x: (bounds.width - 18) / 2, y: bounds.height - 300, width: 18, height: 18)
        closeWebKitCheckbox.frame = NSRect(x: 44, y: bounds.height - 338, width: bounds.width - 88, height: 24)
        logoutButton.frame = NSRect(x: 44, y: 104, width: bounds.width - 88, height: 32)
        madeByButton.frame = NSRect(x: 44, y: 68, width: bounds.width - 88, height: 24)
        donateButton.frame = NSRect(x: 44, y: 36, width: bounds.width - 88, height: 24)
    }

    private func refreshState() {
        switch SpotifydManager.installState() {
        case .notInstalled:
            statusLabel.stringValue = "spotifyd not installed"
            installButton.isEnabled = true
            uninstallButton.isEnabled = false
        case .appManaged(let path):
            statusLabel.stringValue = "spotifyd installed by SpotyPopup\n\(path)"
            installButton.isEnabled = false
            uninstallButton.isEnabled = true
        case .homebrew(let path):
            statusLabel.stringValue = "spotifyd installed with Homebrew\n\(path)"
            installButton.isEnabled = false
            uninstallButton.isEnabled = true
        case .system(let path):
            statusLabel.stringValue = "spotifyd installed outside SpotyPopup\n\(path)"
            installButton.isEnabled = false
            uninstallButton.isEnabled = false
        }
    }

    private func setWorking(_ working: Bool, message: String) {
        installButton.isEnabled = false
        uninstallButton.isEnabled = false
        statusLabel.stringValue = message
        working ? progressIndicator.startAnimation(nil) : progressIndicator.stopAnimation(nil)
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

    @objc private func closeWebKitCheckboxChanged() {
        AppSettings.closeSpotifyWebViewOnBack = closeWebKitCheckbox.state == .on
    }

    @objc private func logoutButtonTapped() {
        onLogout?()
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
            installButton.isEnabled = true
            uninstallButton.isEnabled = false
        case .appManaged, .homebrew:
            installButton.isEnabled = false
            uninstallButton.isEnabled = true
        case .system:
            installButton.isEnabled = false
            uninstallButton.isEnabled = false
        }
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
