import AppKit
import QuartzCore

class StatusBarView: NSView {
    private let imageView = NSImageView()
    private let textField = NSTextField()
    private let textContainer = NSView()
    private var fullText: String = ""
    private let textBoxWidth: CGFloat = 125
    private let imageSize: CGFloat = 16
    private var singleWidth: CGFloat = 0
    private var isHovering: Bool = false
    private var trackingArea: NSTrackingArea?
    
    var onClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupViews() {
        // Image view
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = NSRect(x: 4, y: 3, width: imageSize, height: imageSize)
        addSubview(imageView)

        // Text container with clipping - positioned after image
        let xPos = imageSize + 8
        textContainer.frame = NSRect(x: xPos, y: 2, width: textBoxWidth, height: 18)
        textContainer.wantsLayer = true
        textContainer.layer?.masksToBounds = true
        textContainer.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(textContainer)

        // Text field inside container - starts at 0 relative to container
        textField.isBordered = false
        textField.isEditable = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byClipping
        textField.frame.origin = .zero
        textContainer.addSubview(textField)

        // Setup hover tracking
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        startScrolling()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        stopScrolling()
    }

    func update(image: NSImage?, text: String) {

        if fullText == text {
            return
        }

        stopScrolling()

        imageView.image = image
        fullText = text

        let separator = "   •   "
        let repeatedText = text + separator

        // Duplicate for seamless loop
        textField.stringValue = repeatedText + repeatedText

        // Use sizeToFit to get actual rendered width
        textField.sizeToFit()
        singleWidth = textField.frame.width / 2.0

        // Set text field width to double
        textField.frame = NSRect(x: 0, y: 0, width: singleWidth * 2, height: 18)

        updateLayout()

        // Don't auto-start scrolling - wait for hover
        // Scrolling starts on mouseEntered
    }

    private func updateLayout() {
        let totalWidth = imageSize + 8 + textBoxWidth + 8
        frame = NSRect(x: 0, y: 0, width: totalWidth, height: 22)

        // Update parent button frame
        if let button = superview {
            button.frame = NSRect(x: button.frame.origin.x, y: button.frame.origin.y, width: totalWidth, height: 22)
        }

        needsDisplay = true
    }

    private func startScrolling() {
        // Only scroll if text wider than container AND hovering
        guard singleWidth > textBoxWidth else { return }
        guard isHovering else { return }

        stopScrolling()

        textField.wantsLayer = true
        guard let layer = textField.layer else { return }

        // Calculate duration for smooth 30px/sec scroll
        let duration = Double(singleWidth) / 30.0

        // Create infinite animation
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -singleWidth
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false

        layer.add(animation, forKey: "scrollAnimation")
    }

    private func stopScrolling() {
        textField.layer?.removeAnimation(forKey: "scrollAnimation")
        textField.layer?.transform = CATransform3DIdentity
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopScrolling()
        }
    }

    deinit {
        stopScrolling()
    }
}
