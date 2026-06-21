import AppKit

class MenuView: NSView {
    private let api: SpotifyAPI
    private let auth: SpotifyAuth
    var onPreferredSizeChange: ((NSSize) -> Void)?
    private let backgroundEffectView = NSVisualEffectView()

    // Login view
    private let loginView = NSView()
    private let loginIconView = NSImageView()
    private let loginLabel = NSTextField(labelWithString: "Not authenticated")
    private let clientIDField = NSTextField()
    private let clientIDLabel = NSTextField(labelWithString: "Client ID:")
    private let guideLink = NSButton()
    private let loginButton = NSButton()
    private let quitButton = NSButton()

    // Header bar
    private let headerBar = NSView()
    private let deviceButton = NSButton()
    private let queueButton = NSButton()
    private let volumeButton = NSButton()
    private let volumeSlider = NSSlider()

    // Playback view
    private let playbackView = NSView()
    private let albumArtView = NSImageView()
    private let trackNameLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    private let progressBarView = ProgressBarView(frame: .zero)
    private let previousButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    private let webPlayerButton = NSButton()

    // No playback view
    private let noPlaybackView = NSView()
    private let noPlaybackIconView = NSImageView()
    private let noPlaybackLabel = NSTextField(labelWithString: "No active playback")
    private let noPlaybackSubLabel = NSTextField(labelWithString: "Start playing on Spotify")
    private let refreshButton = NSButton()

    // Devices view
    private let devicesView = DevicesView()

    // Queue view
    private let queueView = QueueView()

    // Spotify web player view
    private let spotifyWebView = SpotifyWebPlayerView()

    private var showQueue = false
    private var showVolumeControl = false
    private var showDevices = false
    private var showSpotifyWeb = false

    private var imageCache = [String: NSImage]()
private var currentAlbumArtURL: String?
private var lastTrackId: String?
private var lastIsPlaying: Bool?
private var pendingWebCloseWorkItem: DispatchWorkItem?

    init(api: SpotifyAPI, auth: SpotifyAuth, onPreferredSizeChange: ((NSSize) -> Void)? = nil) {
        self.api = api
        self.auth = auth
        self.onPreferredSizeChange = onPreferredSizeChange
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        setupViews()
        observeChanges()
        updateVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.clear.cgColor

        backgroundEffectView.material = .hudWindow
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)
        
        setupLoginView()
        setupHeaderBar()
        setupPlaybackView()
        setupNoPlaybackView()
        setupDevicesView()
        setupQueueView()
        setupSpotifyWebView()
        setupWebPlayerButton()
    }

    private func setupLoginView() {
        loginView.wantsLayer = true

        if let iconPath = Bundle.main.resourcePath?.appending("/AppIcon_login.png"),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            loginIconView.image = iconImage
            loginIconView.imageScaling = .scaleProportionallyUpOrDown
        }
        loginView.addSubview(loginIconView)

        loginLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        loginLabel.alignment = .center
        loginView.addSubview(loginLabel)

        clientIDLabel.font = NSFont.systemFont(ofSize: 13)
        clientIDLabel.alignment = .left
        loginView.addSubview(clientIDLabel)

        clientIDField.placeholderString = "Enter your Spotify Client ID"
        clientIDField.isBordered = true
        clientIDField.bezelStyle = .roundedBezel
        if let savedClientID = UserDefaults.standard.string(forKey: "spotify_client_id") {
            clientIDField.stringValue = savedClientID
        }
        loginView.addSubview(clientIDField)

        guideLink.title = "How to get Client ID?"
        guideLink.bezelStyle = .inline
        guideLink.isBordered = false
        guideLink.target = self
        guideLink.action = #selector(guideLinkTapped)
        guideLink.attributedTitle = NSAttributedString(
            string: "How to get Client ID?",
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.systemFont(ofSize: 12)
            ]
        )
        loginView.addSubview(guideLink)

        loginButton.title = "Login with Spotify"
        loginButton.bezelStyle = .rounded
        loginButton.target = self
        loginButton.action = #selector(loginButtonTapped)
        loginView.addSubview(loginButton)

        quitButton.title = "Quit"
        quitButton.bezelStyle = .rounded
        quitButton.target = self
        quitButton.action = #selector(quitButtonTapped)
        loginView.addSubview(quitButton)

        addSubview(loginView)
    }

    private func setupHeaderBar() {
        headerBar.wantsLayer = true
        headerBar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.06).cgColor

        deviceButton.image = NSImage(systemSymbolName: "hifispeaker.fill", accessibilityDescription: nil)
        deviceButton.bezelStyle = .recessed
        deviceButton.isBordered = false
        deviceButton.target = self
        deviceButton.action = #selector(deviceButtonTapped)
        deviceButton.toolTip = "Switch device"
        headerBar.addSubview(deviceButton)

        queueButton.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: nil)
        queueButton.bezelStyle = .recessed
        queueButton.isBordered = false
        queueButton.target = self
        queueButton.action = #selector(queueButtonTapped)
        queueButton.toolTip = "Show queue"
        headerBar.addSubview(queueButton)

        volumeButton.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)
        volumeButton.bezelStyle = .recessed
        volumeButton.isBordered = false
        volumeButton.target = self
        volumeButton.action = #selector(volumeButtonTapped)
        volumeButton.toolTip = "Volume"
        headerBar.addSubview(volumeButton)

        volumeSlider.minValue = 0
        volumeSlider.maxValue = 100
        volumeSlider.doubleValue = Double(AppSettings.spotifyVolume)
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeSliderChanged)
        headerBar.addSubview(volumeSlider)

        addSubview(headerBar)
    }

    private func setupPlaybackView() {
        playbackView.wantsLayer = true

        albumArtView.imageScaling = .scaleProportionallyUpOrDown
        albumArtView.wantsLayer = true
        albumArtView.layer?.cornerRadius = 8
        albumArtView.layer?.masksToBounds = true
        albumArtView.toolTip = "Open Spotify Web Player"
        albumArtView.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(albumArtTapped)))
        playbackView.addSubview(albumArtView)

        trackNameLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        trackNameLabel.alignment = .center
        trackNameLabel.isBordered = false
        trackNameLabel.isEditable = false
        trackNameLabel.drawsBackground = false
        trackNameLabel.lineBreakMode = .byTruncatingTail
        trackNameLabel.maximumNumberOfLines = 2
        trackNameLabel.toolTip = "Open album in Spotify Web Player"
        trackNameLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(trackNameTapped)))
        playbackView.addSubview(trackNameLabel)

        artistLabel.font = NSFont.systemFont(ofSize: 14)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.alignment = .center
        artistLabel.isBordered = false
        artistLabel.isEditable = false
        artistLabel.drawsBackground = false
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.toolTip = "Open artist in Spotify Web Player"
        artistLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(artistNameTapped)))
        playbackView.addSubview(artistLabel)

        playbackView.addSubview(progressBarView)

        let controlConfig = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        previousButton.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)?.withSymbolConfiguration(controlConfig)
        previousButton.bezelStyle = .recessed
        previousButton.isBordered = false
        previousButton.target = self
        previousButton.action = #selector(previousButtonTapped)
        playbackView.addSubview(previousButton)

        playPauseButton.bezelStyle = .recessed
        playPauseButton.isBordered = false
        playPauseButton.target = self
        playPauseButton.action = #selector(playPauseButtonTapped)
        playbackView.addSubview(playPauseButton)

        nextButton.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)?.withSymbolConfiguration(controlConfig)
        nextButton.bezelStyle = .recessed
        nextButton.isBordered = false
        nextButton.target = self
        nextButton.action = #selector(nextButtonTapped)
        playbackView.addSubview(nextButton)

        addSubview(playbackView)
    }

    private func setupNoPlaybackView() {
        noPlaybackView.wantsLayer = true

        noPlaybackIconView.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)
        noPlaybackIconView.contentTintColor = .secondaryLabelColor
        noPlaybackView.addSubview(noPlaybackIconView)

        noPlaybackLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        noPlaybackLabel.alignment = .center
        noPlaybackView.addSubview(noPlaybackLabel)

        noPlaybackSubLabel.font = NSFont.systemFont(ofSize: 14)
        noPlaybackSubLabel.textColor = .secondaryLabelColor
        noPlaybackSubLabel.alignment = .center
        noPlaybackView.addSubview(noPlaybackSubLabel)

        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonTapped)
        noPlaybackView.addSubview(refreshButton)

        addSubview(noPlaybackView)
    }

    private func setupDevicesView() {
        devicesView.configure(devices: [], onBack: { [weak self] in
            self?.showDevices = false
            self?.updateVisibility()
        }, onDeviceSelected: { [weak self] deviceId in
            Task {
                await self?.api.transferPlayback(to: deviceId)
                self?.showDevices = false
                DispatchQueue.main.async {
                    self?.updateVisibility()
                }
            }
        }, onRefresh: { [weak self] in
            Task {
                await self?.api.fetchAvailableDevices()
            }
        })
        addSubview(devicesView)
    }

    private func setupQueueView() {
        queueView.onClose = { [weak self] in
            self?.showQueue = false
            self?.updateVisibility()
        }
        addSubview(queueView)
    }

    private func setupSpotifyWebView() {
        spotifyWebView.onBack = { [weak self] in
            guard let self else { return }

            self.spotifyWebView.capturePreview()
            self.pendingWebCloseWorkItem?.cancel()

            switch AppSettings.spotifyWebMemoryPolicy {
            case .instant:
                self.spotifyWebView.close()
            case .after30Seconds:
                let workItem = DispatchWorkItem { [weak self] in
                    self?.spotifyWebView.close()
                }
                self.pendingWebCloseWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
            case .never:
                break
            }

            self.showSpotifyWeb = false
            self.onPreferredSizeChange?(NSSize(width: 320, height: 480))
            self.updateVisibility()
        }
        addSubview(spotifyWebView)
    }

    private func setupWebPlayerButton() {
        webPlayerButton.image = NSImage(systemSymbolName: "safari.fill", accessibilityDescription: nil)
        webPlayerButton.bezelStyle = .recessed
        webPlayerButton.isBordered = false
        webPlayerButton.target = self
        webPlayerButton.action = #selector(webPlayerButtonTapped)
        webPlayerButton.toolTip = "Open Spotify Web Player"
        addSubview(webPlayerButton)
    }

    override func layout() {
        super.layout()
        backgroundEffectView.frame = bounds
        
        // Login view
        if !loginView.isHidden {
            loginView.frame = bounds
            loginIconView.frame = NSRect(x: (bounds.width - 40) / 2, y: bounds.height / 2 + 100, width: 40, height: 40)
            loginLabel.frame = NSRect(x: 40, y: bounds.height / 2 + 60, width: bounds.width - 80, height: 24)
            clientIDLabel.frame = NSRect(x: 40, y: bounds.height / 2 + 30, width: bounds.width - 80, height: 18)
            clientIDField.frame = NSRect(x: 40, y: bounds.height / 2, width: bounds.width - 80, height: 24)
            guideLink.frame = NSRect(x: 40, y: bounds.height / 2 - 25, width: bounds.width - 80, height: 20)
            loginButton.frame = NSRect(x: (bounds.width - 200) / 2, y: bounds.height / 2 - 60, width: 200, height: 32)
            quitButton.frame = NSRect(x: (bounds.width - 200) / 2, y: bounds.height / 2 - 100, width: 200, height: 32)
        }

        // Header bar
        if !headerBar.isHidden {
            headerBar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 48)

            let iconSize: CGFloat = 28
            let iconY: CGFloat = 10
            var xPos: CGFloat = 12

            deviceButton.frame = NSRect(x: xPos, y: iconY, width: iconSize, height: iconSize)
            xPos += iconSize + 12
            
            queueButton.frame = NSRect(x: xPos, y: iconY, width: iconSize, height: iconSize)
            xPos += iconSize + 12
            
            volumeButton.frame = NSRect(x: xPos, y: iconY, width: iconSize, height: iconSize)
            volumeSlider.frame = NSRect(x: xPos + iconSize + 4, y: iconY + 4, width: 80, height: 20)
            volumeSlider.isHidden = !showVolumeControl
        }

        // Playback view
        if !playbackView.isHidden {
            playbackView.frame = NSRect(x: 0, y: 48, width: bounds.width, height: bounds.height - 48)

            let pbHeight = playbackView.bounds.height
            let topMargin: CGFloat = 20
            var yPos = pbHeight - topMargin

            // Album art at top with consistent margins
            yPos -= 240
            albumArtView.frame = NSRect(x: 40, y: yPos, width: 240, height: 240)

            // Track name below album
            yPos -= 12
            let trackNameHeight: CGFloat = 22
            trackNameLabel.frame = NSRect(x: 20, y: yPos - trackNameHeight, width: bounds.width - 40, height: trackNameHeight)
            yPos -= trackNameHeight

            // Artist below track name (reduced gap)
            yPos -= 4
            let artistHeight: CGFloat = 18
            artistLabel.frame = NSRect(x: 20, y: yPos - artistHeight, width: bounds.width - 40, height: artistHeight)
            yPos -= artistHeight

            // Progress bar below artist
            yPos -= 12
            let progressBarHeight: CGFloat = 50
            progressBarView.frame = NSRect(x: 0, y: yPos - progressBarHeight, width: bounds.width, height: progressBarHeight)

            // Controls at bottom
            let controlsY: CGFloat = 16
            let centerX = bounds.width / 2

            playPauseButton.frame = NSRect(x: centerX - 24, y: controlsY, width: 48, height: 48)
            previousButton.frame = NSRect(x: centerX - 80, y: controlsY + 4, width: 40, height: 40)
            nextButton.frame = NSRect(x: centerX + 40, y: controlsY + 4, width: 40, height: 40)
        }

        // No playback view
        if !noPlaybackView.isHidden {
            noPlaybackView.frame = NSRect(x: 0, y: 48, width: bounds.width, height: bounds.height - 48)
            noPlaybackIconView.frame = NSRect(x: (bounds.width - 40) / 2, y: noPlaybackView.bounds.height / 2 + 60, width: 40, height: 40)
            noPlaybackLabel.frame = NSRect(x: 40, y: noPlaybackView.bounds.height / 2 + 20, width: bounds.width - 80, height: 24)
            noPlaybackSubLabel.frame = NSRect(x: 40, y: noPlaybackView.bounds.height / 2 - 10, width: bounds.width - 80, height: 20)
            refreshButton.frame = NSRect(x: (bounds.width - 120) / 2, y: noPlaybackView.bounds.height / 2 - 50, width: 120, height: 32)
        }

        // Devices view
        if !devicesView.isHidden {
            devicesView.frame = bounds
        }

        // Queue view
        if !queueView.isHidden {
            queueView.frame = bounds
        }

        // Spotify web player view
        if !spotifyWebView.isHidden {
            spotifyWebView.frame = bounds
        }

        webPlayerButton.frame = NSRect(x: bounds.width - 44, y: 12, width: 32, height: 32)
    }

    private func observeChanges() {
        // Observe auth state
        auth.$isAuthenticated
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)

        // Observe playback changes
        api.$currentPlayback
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePlaybackView()
            }
            .store(in: &cancellables)

        // Observe devices - only update when showing
        api.$availableDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.showDevices else { return }
                self.updateDevicesView()
            }
            .store(in: &cancellables)

        // Observe queue - only update when showing
        api.$queue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.showQueue else { return }
                self.updateQueueView()
            }
            .store(in: &cancellables)

        api.$isSkippingQueueTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSkipping in
                self?.queueView.setLoading(isSkipping)
                self?.updatePlaybackControls()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateVisibility() {
        let authenticated = auth.isAuthenticated
        let hasPlayback = api.currentPlayback?.item != nil

        loginView.isHidden = authenticated
        headerBar.isHidden = !authenticated || showQueue || showDevices || showSpotifyWeb
        playbackView.isHidden = !authenticated || !hasPlayback || showQueue || showDevices || showSpotifyWeb
        noPlaybackView.isHidden = !authenticated || hasPlayback || showQueue || showDevices || showSpotifyWeb
        devicesView.isHidden = !showDevices || showSpotifyWeb
        queueView.isHidden = !showQueue || showSpotifyWeb
    spotifyWebView.isHidden = !showSpotifyWeb
    webPlayerButton.isHidden = !authenticated || showQueue || showDevices || showSpotifyWeb

    updatePlaybackControls()
    needsLayout = true
    }

    private func updatePlaybackControls() {
        let controlsEnabled = !api.isSkippingQueueTrack
        previousButton.isEnabled = controlsEnabled
        nextButton.isEnabled = controlsEnabled
        previousButton.alphaValue = controlsEnabled ? 1 : 0.35
        nextButton.alphaValue = controlsEnabled ? 1 : 0.35
    }

    private func updatePlaybackView() {
        guard let playback = api.currentPlayback, let track = playback.item else {
            lastTrackId = nil
            lastIsPlaying = nil
            updateVisibility()
            return
        }

        // Skip if nothing changed
        if lastTrackId == track.id && lastIsPlaying == playback.isPlaying {
            return
        }

        lastTrackId = track.id
        lastIsPlaying = playback.isPlaying

        trackNameLabel.stringValue = track.name
        artistLabel.stringValue = track.artistNames

        let playPauseIcon = playback.isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let playPauseConfig = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        playPauseButton.image = NSImage(systemSymbolName: playPauseIcon, accessibilityDescription: nil)?.withSymbolConfiguration(playPauseConfig)

        progressBarView.configure(playback: playback, track: track) { [weak self] newPositionMs in
            Task {
                await self?.api.seekToPosition(newPositionMs)
            }
        }

        if let artURL = track.albumArtURL {
            // Only load if URL changed
            if currentAlbumArtURL != artURL {
                currentAlbumArtURL = artURL

                if let cached = imageCache[artURL] {
                    albumArtView.image = cached
                } else if let url = URL(string: artURL) {
                    loadAlbumArt(from: url, artURL: artURL)
                }
            }
        } else {
            currentAlbumArtURL = nil
            albumArtView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        }

        updateVisibility()
    }

    private func loadAlbumArt(from url: URL, artURL: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.imageCache[artURL] = image
                self?.albumArtView.image = image
            }
        }.resume()
    }

    private func updateDevicesView() {
        devicesView.configure(
            devices: api.availableDevices,
            onBack: { [weak self] in
                self?.showDevices = false
                self?.updateVisibility()
            },
            onDeviceSelected: { [weak self] deviceId in
                Task {
                    await self?.api.transferPlayback(to: deviceId)
                    self?.showDevices = false
                    DispatchQueue.main.async {
                        self?.updateVisibility()
                    }
                }
            },
            onRefresh: { [weak self] in
                Task {
                    await self?.api.fetchAvailableDevices()
                }
            }
        )
    }

    private func updateQueueView() {
        queueView.configure(
        queue: api.queue,
        currentTrack: api.currentPlayback?.item,
        onClose: { [weak self] in
            self?.showQueue = false
            self?.updateVisibility()
        },
        maxSkippableTracks: SpotifyAPI.maxQueueSkipCount,
        onTrackSelected: { [weak self] index in
            guard let self, index < SpotifyAPI.maxQueueSkipCount, !self.api.isSkippingQueueTrack else { return }

            Task {
                await self.api.skipToQueuedTrack(at: index)
            }
        }
        )
    }

    // MARK: - Actions

    @objc private func loginButtonTapped() {
        let clientID = clientIDField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !clientID.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Client ID Required"
            alert.informativeText = "Please enter your Spotify Client ID"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        UserDefaults.standard.set(clientID, forKey: "spotify_client_id")
        auth.setClientID(clientID)
        auth.authenticate()
    }

    @objc private func guideLinkTapped() {
        if let url = URL(string: "https://github.com/LoneDev6/SpotyPopup/blob/main/SETUP_GUIDE.md") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitButtonTapped() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func deviceButtonTapped() {
        showDevices.toggle()
        if showDevices {
            Task {
                await api.fetchAvailableDevices()
            }
        }
        updateVisibility()
    }

    @objc private func queueButtonTapped() {
        showQueue.toggle()
        if showQueue {
            Task { [weak self] in
                await self?.api.fetchQueue()
                DispatchQueue.main.async {
                    self?.queueView.scrollToTop()
                }
            }
        }
        updateVisibility()

        if showQueue {
            DispatchQueue.main.async { [weak self] in
                self?.queueView.scrollToTop()
            }
        }
    }

    @objc private func volumeButtonTapped() {
        showVolumeControl.toggle()
        volumeSlider.isHidden = !showVolumeControl
    }

    @objc private func volumeSliderChanged() {
        let volume = Int(volumeSlider.doubleValue)
        AppSettings.spotifyVolume = volume
        Task {
            await api.setVolume(volume)
        }
    }

    @objc private func previousButtonTapped() {
        guard !api.isSkippingQueueTrack else { return }
        Task {
            await api.previousTrack()
        }
    }

    @objc private func playPauseButtonTapped() {
        // Immediately flip icon for instant feedback
        let wasPlaying = api.currentPlayback?.isPlaying == true
        let newIcon = wasPlaying ? "play.circle.fill" : "pause.circle.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        playPauseButton.image = NSImage(systemSymbolName: newIcon, accessibilityDescription: nil)?.withSymbolConfiguration(config)

        Task {
            if wasPlaying {
                await api.pause()
            } else {
                await api.play()
            }
        }
    }

    @objc private func nextButtonTapped() {
        guard !api.isSkippingQueueTrack else { return }
        Task {
            await api.nextTrack()
        }
    }

    @objc private func refreshButtonTapped() {
        Task {
            await api.fetchCurrentPlayback()
        }
    }

    @objc private func webPlayerButtonTapped() {
        openSpotifyWeb()
    }

    @objc private func albumArtTapped() {
        openSpotifyWeb()
    }

    @objc private func trackNameTapped() {
        guard let albumId = api.currentPlayback?.item?.album.id,
              let url = URL(string: "https://open.spotify.com/album/\(albumId)?nd=1") else {
            openSpotifyWeb()
            return
        }

        openSpotifyWeb(url: url)
    }

    @objc private func artistNameTapped() {
        guard let artistId = api.currentPlayback?.item?.artists.first?.id,
              let url = URL(string: "https://open.spotify.com/artist/\(artistId)?nd=1") else {
            openSpotifyWeb()
            return
        }

        openSpotifyWeb(url: url)
    }

    private func openSpotifyWeb(url: URL? = nil) {
        pendingWebCloseWorkItem?.cancel()
        pendingWebCloseWorkItem = nil
        spotifyWebView.prepareForPresentation()

        showSpotifyWeb = true
        showQueue = false
        showDevices = false
        onPreferredSizeChange?(NSSize(width: 1280, height: 820))
        updateVisibility()

        if let url {
            spotifyWebView.open(url)
        } else {
            spotifyWebView.open()
        }
    }
}

// MARK: - DevicesView

class DevicesView: NSView {
    private let backgroundEffectView = NSVisualEffectView()
    private let headerLabel = NSTextField(labelWithString: "Devices")
    private let refreshButton = NSButton()
    private let backButton = NSButton()
    private let scrollView = NSScrollView()
    private let deviceListContainer = NSView()
    private let emptyView = NSView()
    private let emptyIconView = NSImageView()
    private let emptyLabel = NSTextField(labelWithString: "No devices found")
    private let emptyRefreshButton = NSButton()

    private var deviceRowViews: [DeviceRow] = []
    private var onDeviceSelected: ((String) -> Void)?
    private var onRefresh: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
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
        
        headerLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        headerLabel.alignment = .center
        addSubview(headerLabel)

        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        refreshButton.bezelStyle = .recessed
        refreshButton.isBordered = false
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonTapped)
        addSubview(refreshButton)

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = deviceListContainer
        addSubview(scrollView)

        backButton.title = "Back"
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
        backButton.imagePosition = .imageLeft
        backButton.imageHugsTitle = true
        backButton.bezelStyle = .recessed
        backButton.isBordered = false
        backButton.target = self
        backButton.action = #selector(backButtonTapped)
        backButton.alignment = .left
        backButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        backButton.contentTintColor = .labelColor
        addSubview(backButton)

        // Empty state
        emptyIconView.image = NSImage(systemSymbolName: "hifispeaker", accessibilityDescription: nil)
        emptyIconView.contentTintColor = .secondaryLabelColor
        emptyView.addSubview(emptyIconView)

        emptyLabel.font = NSFont.systemFont(ofSize: 14)
        emptyLabel.textColor = .secondaryLabelColor
        emptyView.addSubview(emptyLabel)

        emptyRefreshButton.title = "Refresh"
        emptyRefreshButton.bezelStyle = .rounded
        emptyRefreshButton.target = self
        emptyRefreshButton.action = #selector(refreshButtonTapped)
        emptyView.addSubview(emptyRefreshButton)

        addSubview(emptyView)
    }

    override func layout() {
        super.layout()
        backgroundEffectView.frame = bounds
        
        headerLabel.frame = NSRect(x: 40, y: bounds.height - 40, width: bounds.width - 80, height: 24)
        refreshButton.frame = NSRect(x: bounds.width - 36, y: bounds.height - 38, width: 20, height: 20)

        scrollView.frame = NSRect(x: 0, y: 60, width: bounds.width, height: bounds.height - 120)

        layoutDeviceList()

        backButton.frame = NSRect(x: 16, y: 0, width: max(0, bounds.width - 16), height: 52)

        // Empty state
        emptyView.frame = NSRect(x: 0, y: 60, width: bounds.width, height: bounds.height - 120)
        emptyIconView.frame = NSRect(x: (bounds.width - 40) / 2, y: emptyView.bounds.height / 2 + 40, width: 40, height: 40)
        emptyLabel.frame = NSRect(x: 40, y: emptyView.bounds.height / 2, width: bounds.width - 80, height: 20)
        emptyRefreshButton.frame = NSRect(x: (bounds.width - 120) / 2, y: emptyView.bounds.height / 2 - 40, width: 120, height: 32)
    }

    private func layoutDeviceList() {
        var yOffset: CGFloat = 0
        let totalHeight = CGFloat(deviceRowViews.count * 60)

        deviceListContainer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(totalHeight, scrollView.frame.height))

        for rowView in deviceRowViews.reversed() {
            rowView.frame = NSRect(x: 0, y: yOffset, width: bounds.width, height: 60)
            yOffset += 60
        }
    }

    func configure(devices: [Device], onBack: @escaping () -> Void, onDeviceSelected: @escaping (String) -> Void, onRefresh: @escaping () -> Void) {
        self.onBack = onBack
        self.onDeviceSelected = onDeviceSelected
        self.onRefresh = onRefresh

        deviceRowViews.forEach { $0.removeFromSuperview() }
        deviceRowViews.removeAll()

        emptyView.isHidden = !devices.isEmpty
        scrollView.isHidden = devices.isEmpty

        for device in devices {
            let rowView = DeviceRow()
            rowView.configure(device: device) { [weak self] in
                self?.onDeviceSelected?(device.id)
            }
            deviceListContainer.addSubview(rowView)
            deviceRowViews.append(rowView)
        }

        needsLayout = true
    }

    private var onBack: (() -> Void)?

    @objc private func backButtonTapped() {
        onBack?()
    }

    @objc private func refreshButtonTapped() {
        onRefresh?()
    }
}

class DeviceRow: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let typeLabel = NSTextField(labelWithString: "")
    private let activeIconView = NSImageView()
    private let button = NSButton()

    private var onClick: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 6
        
        button.title = ""
        button.bezelStyle = .recessed
        button.isBordered = false
        button.target = self
        button.action = #selector(buttonTapped)
        addSubview(button)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        nameLabel.isBordered = false
        nameLabel.isEditable = false
        nameLabel.drawsBackground = false
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        typeLabel.isBordered = false
        typeLabel.isEditable = false
        typeLabel.drawsBackground = false
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.font = NSFont.systemFont(ofSize: 12)
        addSubview(typeLabel)

        activeIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        activeIconView.contentTintColor = .systemGreen
        addSubview(activeIconView)
    }

    override func layout() {
        super.layout()

        button.frame = bounds

        iconView.frame = NSRect(x: 12, y: 18, width: 24, height: 24)
        nameLabel.frame = NSRect(x: 48, y: 28, width: bounds.width - 80, height: 18)
        typeLabel.frame = NSRect(x: 48, y: 10, width: bounds.width - 80, height: 16)
        activeIconView.frame = NSRect(x: bounds.width - 32, y: 22, width: 16, height: 16)
    }

    func configure(device: Device, onClick: @escaping () -> Void) {
        self.onClick = onClick

        nameLabel.stringValue = device.name
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: device.isActive ? .semibold : .regular)

        typeLabel.stringValue = device.type.capitalized

        iconView.image = NSImage(systemSymbolName: deviceIcon(for: device.type), accessibilityDescription: nil)
        iconView.contentTintColor = device.isActive ? .systemGreen : .secondaryLabelColor
        layer?.backgroundColor = device.isActive
            ? NSColor.systemGreen.withAlphaComponent(0.12).cgColor
            : NSColor.clear.cgColor
        
        activeIconView.isHidden = !device.isActive

        needsLayout = true
    }

    private func deviceIcon(for type: String) -> String {
        switch type.lowercased() {
        case "computer": return "laptopcomputer"
        case "smartphone": return "iphone"
        case "speaker": return "hifispeaker.fill"
        case "tv": return "tv"
        case "avr": return "amplifier"
        case "stb": return "appletv"
        case "audio_dongle": return "cable.connector"
        case "game_console": return "gamecontroller"
        case "cast_video": return "airplayvideo"
        case "cast_audio": return "airplayaudio"
        case "automobile": return "car"
        default: return "music.note"
        }
    }

    @objc private func buttonTapped() {
        onClick?()
    }
}

import Combine
