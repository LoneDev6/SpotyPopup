import AppKit

class QueueView: NSView {
    private let backgroundEffectView = NSVisualEffectView()
    private let headerLabel = NSTextField(labelWithString: "Queue")
    private let closeButton = NSButton()
    private let nowPlayingLabel = NSTextField(labelWithString: "Now Playing")
    private let nextInQueueLabel = NSTextField(labelWithString: "Next in Queue")
    private let scrollView = NSScrollView()
    private let trackListContainer = NSView()
    private let loadingOverlayView = NSVisualEffectView()
    private let loadingSpinner = NSProgressIndicator()
    private let emptyStateView = NSView()
    private let emptyIconView = NSImageView()
    private let emptyLabel = NSTextField(labelWithString: "Queue is empty")
    private let backButton = NSButton()

    private var trackRowViews: [QueueTrackRow] = []
    private var currentTrackView: QueueTrackRow?

    var onClose: (() -> Void)?
    var onTrackSelected: ((Int) -> Void)?

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
        
        // Header label
        headerLabel.font = NSFont.boldSystemFont(ofSize: 18)
        headerLabel.textColor = .labelColor
        addSubview(headerLabel)

        // Close button
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        closeButton.bezelStyle = .recessed
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeButtonTapped)
        addSubview(closeButton)

        // Now playing label
        nowPlayingLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nowPlayingLabel.textColor = .secondaryLabelColor
        addSubview(nowPlayingLabel)

        // Next in queue label
        nextInQueueLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nextInQueueLabel.textColor = .secondaryLabelColor
        addSubview(nextInQueueLabel)

        // Scroll view
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = trackListContainer
        addSubview(scrollView)

        loadingOverlayView.material = .hudWindow
        loadingOverlayView.blendingMode = .withinWindow
        loadingOverlayView.state = .active
        loadingOverlayView.wantsLayer = true
        loadingOverlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        loadingOverlayView.alphaValue = 0
        loadingOverlayView.isHidden = true
        addSubview(loadingOverlayView)

        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .regular
        loadingOverlayView.addSubview(loadingSpinner)

        // Empty state
        emptyIconView.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)
        emptyIconView.contentTintColor = .secondaryLabelColor
        emptyStateView.addSubview(emptyIconView)

        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyStateView.addSubview(emptyLabel)

        addSubview(emptyStateView)
        emptyStateView.isHidden = true

        backButton.title = "Back"
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
        backButton.imagePosition = .imageLeft
        backButton.imageHugsTitle = true
        backButton.bezelStyle = .recessed
        backButton.isBordered = false
        backButton.target = self
        backButton.action = #selector(closeButtonTapped)
        backButton.alignment = .left
        backButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        backButton.contentTintColor = .labelColor
        addSubview(backButton)
    }

    override func layout() {
        super.layout()
        backgroundEffectView.frame = bounds
        
        // Header
        closeButton.frame = NSRect(x: bounds.width - 40, y: bounds.height - 40, width: 24, height: 24)
        headerLabel.sizeToFit()
        headerLabel.frame.origin = NSPoint(x: 20, y: bounds.height - 40)

        var yOffset = bounds.height - 70

        // Current track section
        if let currentView = currentTrackView {
            nowPlayingLabel.sizeToFit()
            nowPlayingLabel.frame.origin = NSPoint(x: 20, y: yOffset)
            yOffset -= 28

            currentView.frame = NSRect(x: 0, y: yOffset - 64, width: bounds.width, height: 64)
            yOffset -= 80
        }

        // Next in queue label
        if !trackRowViews.isEmpty {
            nextInQueueLabel.sizeToFit()
            nextInQueueLabel.frame.origin = NSPoint(x: 20, y: yOffset)
            yOffset -= 32
        }

        // Scroll view with track list
        let footerHeight: CGFloat = 52
        scrollView.frame = NSRect(x: 0, y: footerHeight, width: bounds.width, height: max(0, yOffset - footerHeight))
        loadingOverlayView.frame = scrollView.frame
        loadingSpinner.frame = NSRect(
            x: (loadingOverlayView.bounds.width - 32) / 2,
            y: (loadingOverlayView.bounds.height - 32) / 2,
            width: 32,
            height: 32
        )
        backButton.frame = NSRect(x: 16, y: 0, width: max(0, bounds.width - 16), height: footerHeight)

        layoutTrackList()

        // Empty state
        if emptyStateView.isHidden == false {
            emptyIconView.frame = NSRect(
                x: (bounds.width - 48) / 2,
                y: bounds.height / 2 + 20,
                width: 48,
                height: 48
            )
            emptyLabel.sizeToFit()
            emptyLabel.frame.origin = NSPoint(
                x: (bounds.width - emptyLabel.frame.width) / 2,
                y: bounds.height / 2 - 20
            )
        }
    }

    private func layoutTrackList() {
        var yOffset: CGFloat = 0
        let totalHeight = CGFloat(trackRowViews.count * 60)

        trackListContainer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(totalHeight, scrollView.frame.height))

        for rowView in trackRowViews.reversed() {
            rowView.frame = NSRect(x: 0, y: yOffset, width: bounds.width, height: 60)
            yOffset += 60
        }
    }

    func scrollToTop() {
        layoutSubtreeIfNeeded()

        guard let documentView = scrollView.documentView else { return }

        let topY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func setLoading(_ isLoading: Bool) {
        if isLoading {
            loadingOverlayView.isHidden = false
            loadingSpinner.startAnimation(nil)
        } else {
            loadingSpinner.stopAnimation(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            loadingOverlayView.animator().alphaValue = isLoading ? 1 : 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.loadingOverlayView.isHidden = !isLoading
        }
    }

    private var lastQueueIds: [String] = []
    private var lastCurrentTrackId: String?

    func configure(queue: [Track], currentTrack: Track?, onClose: @escaping () -> Void, maxSkippableTracks: Int = 10, onTrackSelected: ((Int) -> Void)? = nil) {
        self.onClose = onClose
        self.onTrackSelected = onTrackSelected

        let queueIds = queue.map(\.id)
        let currentId = currentTrack?.id

        // Only rebuild if changed
        let queueChanged = queueIds != lastQueueIds
        let currentChanged = currentId != lastCurrentTrackId

        guard queueChanged || currentChanged else { return }

        lastQueueIds = queueIds
        lastCurrentTrackId = currentId

        // Clear existing views
        currentTrackView?.removeFromSuperview()
        currentTrackView = nil
        trackRowViews.forEach { $0.removeFromSuperview() }
        trackRowViews.removeAll()

        // Show/hide sections
        let isEmpty = queue.isEmpty && currentTrack == nil
        emptyStateView.isHidden = !isEmpty
        nowPlayingLabel.isHidden = currentTrack == nil
        nextInQueueLabel.isHidden = queue.isEmpty

        if let current = currentTrack {
            let currentRow = QueueTrackRow()
            currentRow.configure(track: current, isPlaying: true)
            addSubview(currentRow)
            currentTrackView = currentRow
        }

        for (index, track) in queue.enumerated() {
            let rowView = QueueTrackRow()
            rowView.configure(track: track, isPlaying: false, isSelectable: index < maxSkippableTracks)
            rowView.onClick = { [weak self] in
                self?.onTrackSelected?(index)
            }
            trackListContainer.addSubview(rowView)
            trackRowViews.append(rowView)
        }

        if !queue.isEmpty {
            nextInQueueLabel.stringValue = "Next in Queue (\(queue.count) tracks)"
        }

        needsLayout = true
    }

    @objc private func closeButtonTapped() {
        onClose?()
    }
}

class QueueTrackRow: NSView {
    private let albumArtView = NSImageView()
    private let albumPlayOverlayView = NSView()
    private let albumPlayIconView = NSImageView()
    private let trackNameLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    private let durationLabel = NSTextField(labelWithString: "")
    private let playingIconView = NSImageView()

    private var isPlaying = false
    private var isHovering = false
    private var isSelectable = true
    private var hoverTrackingArea: NSTrackingArea?
    var onClick: (() -> Void)?

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
        
        // Album art
        albumArtView.imageScaling = .scaleProportionallyUpOrDown
        albumArtView.wantsLayer = true
        albumArtView.layer?.cornerRadius = 4
        albumArtView.layer?.masksToBounds = true
        addSubview(albumArtView)

        albumPlayOverlayView.wantsLayer = true
        albumPlayOverlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        albumPlayOverlayView.layer?.cornerRadius = 4
        albumPlayOverlayView.layer?.masksToBounds = true
        albumPlayOverlayView.isHidden = true
        addSubview(albumPlayOverlayView)

        albumPlayIconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        albumPlayIconView.contentTintColor = .white
        albumPlayIconView.imageScaling = .scaleProportionallyDown
        albumPlayOverlayView.addSubview(albumPlayIconView)

        // Track name
        trackNameLabel.isBordered = false
        trackNameLabel.isEditable = false
        trackNameLabel.drawsBackground = false
        trackNameLabel.lineBreakMode = .byTruncatingTail
        addSubview(trackNameLabel)

        // Artist
        artistLabel.isBordered = false
        artistLabel.isEditable = false
        artistLabel.drawsBackground = false
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.font = NSFont.systemFont(ofSize: 12)
        artistLabel.lineBreakMode = .byTruncatingTail
        addSubview(artistLabel)

        // Duration
        durationLabel.isBordered = false
        durationLabel.isEditable = false
        durationLabel.drawsBackground = false
        durationLabel.textColor = .secondaryLabelColor
        durationLabel.font = NSFont.systemFont(ofSize: 13)
        durationLabel.alignment = .right
        addSubview(durationLabel)

        // Playing icon
        playingIconView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)
        playingIconView.contentTintColor = .controlAccentColor
        playingIconView.imageScaling = .scaleProportionallyDown
        addSubview(playingIconView)
    }

    override func layout() {
        super.layout()

        albumArtView.frame = NSRect(x: 20, y: 6, width: 48, height: 48)
        albumPlayOverlayView.frame = albumArtView.frame
        albumPlayIconView.frame = NSRect(x: 15, y: 14, width: 18, height: 20)

        let textX: CGFloat = 80
        let textWidth = bounds.width - textX - 70

        trackNameLabel.frame = NSRect(x: textX, y: 32, width: textWidth, height: 18)
        artistLabel.frame = NSRect(x: textX, y: 12, width: textWidth, height: 16)

        durationLabel.frame = NSRect(x: bounds.width - 70, y: 24, width: 50, height: 16)

        playingIconView.frame = NSRect(x: bounds.width - 47, y: 23, width: 16, height: 16)
        playingIconView.isHidden = !isPlaying
        durationLabel.isHidden = isPlaying
        updateHoverState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateHoverState()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateHoverState()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard isSelectable else { return }
        onClick?()
    }

    func configure(track: Track, isPlaying: Bool, isSelectable: Bool = true) {
        self.isPlaying = isPlaying
        self.isSelectable = isSelectable

        trackNameLabel.stringValue = track.name
        trackNameLabel.font = NSFont.systemFont(ofSize: 14, weight: isPlaying ? .semibold : .regular)

        artistLabel.stringValue = track.artistNames
        durationLabel.stringValue = track.durationFormatted

        if isPlaying {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        updateHoverState()

        if let artURL = track.albumArtURL, let url = URL(string: artURL) {
            loadImage(from: url)
        } else {
            albumArtView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        }

        needsLayout = true
    }

    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
            self?.albumArtView.image = image
        }
        }.resume()
    }

    private func updateHoverState() {
        albumPlayOverlayView.isHidden = isPlaying || !isSelectable || !isHovering
    }
}
