import AppKit

class ProgressBarView: NSView {
    private let backgroundBar = NSView()
    private let progressBar = NSView()
    private let currentTimeLabel = NSTextField(labelWithString: "0:00")
    private let durationLabel = NSTextField(labelWithString: "0:00")

    private var playback: PlaybackState?
    private var track: Track?
    private var onSeek: ((Int) -> Void)?

    private var baseProgressMs: Int = 0
    private var baseTime: Date = Date()
    private var isManualSeek = false
    private var updateTimer: Timer?

    private var localProgressMs: Int {
        guard let playback = playback, playback.isPlaying, !isManualSeek else {
            return baseProgressMs
        }
        let elapsed = Date().timeIntervalSince(baseTime)
        let progressMs = baseProgressMs + Int(elapsed * 1000)
        if let duration = track?.durationMs {
            return min(progressMs, duration)
        }
        return progressMs
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        stopTimer()
    }

    private func setupViews() {
        // Background bar
        backgroundBar.wantsLayer = true
        backgroundBar.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
        backgroundBar.layer?.cornerRadius = 2
        addSubview(backgroundBar)

        // Progress bar
        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        progressBar.layer?.cornerRadius = 2
        addSubview(progressBar)

        // Time labels
        currentTimeLabel.font = NSFont.systemFont(ofSize: 11)
        currentTimeLabel.textColor = .secondaryLabelColor
        addSubview(currentTimeLabel)

        durationLabel.font = NSFont.systemFont(ofSize: 11)
        durationLabel.textColor = .secondaryLabelColor
        addSubview(durationLabel)
    }

    override func layout() {
        super.layout()

        let horizontalPadding: CGFloat = 20
        let barHeight: CGFloat = 4
        let timeLabelSpacing: CGFloat = 4

        // Position bars
        let barY = bounds.height - barHeight - 20
        backgroundBar.frame = NSRect(
            x: horizontalPadding,
            y: barY,
            width: bounds.width - 2 * horizontalPadding,
            height: barHeight
        )

        updateProgressBarWidth()

        // Position time labels below bars
        currentTimeLabel.sizeToFit()
        durationLabel.sizeToFit()

        let labelY = barY - currentTimeLabel.frame.height - timeLabelSpacing
        currentTimeLabel.frame.origin = NSPoint(x: horizontalPadding, y: labelY)
        durationLabel.frame.origin = NSPoint(
            x: bounds.width - horizontalPadding - durationLabel.frame.width,
            y: labelY
        )
    }

    private func updateProgressBarWidth() {
        guard let duration = track?.durationMs, duration > 0 else {
            progressBar.frame = NSRect(
                x: backgroundBar.frame.origin.x,
                y: backgroundBar.frame.origin.y,
                width: 0,
                height: backgroundBar.frame.height
            )
            return
        }

        let progress = min(1.0, Double(localProgressMs) / Double(duration))
        progressBar.frame = NSRect(
            x: backgroundBar.frame.origin.x,
            y: backgroundBar.frame.origin.y,
            width: backgroundBar.frame.width * progress,
            height: backgroundBar.frame.height
        )
    }

    override func mouseDown(with event: NSEvent) {
        handleSeek(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        handleSeek(with: event)
    }

    private func handleSeek(with event: NSEvent) {
        guard let duration = track?.durationMs else { return }

        let locationInView = convert(event.locationInWindow, from: nil)
        let barFrame = backgroundBar.frame

        guard barFrame.contains(locationInView) else { return }

        let relativeX = locationInView.x - barFrame.origin.x
        let progress = max(0, min(1, relativeX / barFrame.width))
        let newPositionMs = Int(Double(duration) * progress)

        baseProgressMs = newPositionMs
        baseTime = Date()
        isManualSeek = true

        updateProgressBarWidth()
        updateTimeLabels()

        onSeek?(newPositionMs)

        // Reset manual seek flag after 500ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isManualSeek = false
        }
    }

    private func startTimer() {
        guard updateTimer == nil else { return }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.window != nil else { return }
            self.updateProgressBarWidth()
            self.updateTimeLabels()
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func updateTimeLabels() {
        currentTimeLabel.stringValue = formatTime(localProgressMs)
        durationLabel.stringValue = formatTime(track?.durationMs)

        currentTimeLabel.sizeToFit()
        durationLabel.sizeToFit()
        needsLayout = true
    }

    private func formatTime(_ ms: Int?) -> String {
        guard let ms = ms else { return "--:--" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func configure(playback: PlaybackState, track: Track, onSeek: @escaping (Int) -> Void) {
        let trackChanged = self.track?.id != track.id
        let progressChanged = self.playback?.progressMs != playback.progressMs

        self.playback = playback
        self.track = track
        self.onSeek = onSeek

        if trackChanged || progressChanged {
            syncProgress()
        }

        updateProgressBarWidth()
        updateTimeLabels()
    }

    private func syncProgress() {
        guard !isManualSeek, let playback = playback else { return }
        baseProgressMs = playback.progressMs
        baseTime = Date()
    }
}
