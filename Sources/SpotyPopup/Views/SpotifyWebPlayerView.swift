import AppKit
import CoreImage
import WebKit

final class SpotifyWebPlayerView: NSView, WKNavigationDelegate {
    private let topBar = NSVisualEffectView()
    private var webView: WKWebView?
    private let snapshotImageView = NSImageView()
    private let loadingBlurView = NSVisualEffectView()
    private let loadingOverlay = NSView()
    private let loadingSpinner = NSProgressIndicator()
    private let backButton = NSButton()
    private let reloadButton = NSButton()
    private var didLoad = false
    private var readinessAttempt = 0
    private var presentationReady = true
    private var pendingRevealAfterPresentation = false

    var onBack: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        snapshotImageView.imageScaling = .scaleAxesIndependently
        snapshotImageView.wantsLayer = true
        snapshotImageView.layer?.backgroundColor = NSColor.black.cgColor
        snapshotImageView.layer?.masksToBounds = true
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(14, forKey: kCIInputRadiusKey)
            snapshotImageView.layer?.filters = [blurFilter]
        }
        snapshotImageView.image = loadSnapshotFromDisk()
        snapshotImageView.isHidden = true
        addSubview(snapshotImageView)

        loadingBlurView.material = .hudWindow
        loadingBlurView.blendingMode = .withinWindow
        loadingBlurView.state = .active
        loadingBlurView.isHidden = true
        addSubview(loadingBlurView)

        loadingOverlay.wantsLayer = true
        loadingOverlay.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(loadingOverlay)

        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .regular
        loadingSpinner.isDisplayedWhenStopped = true
        loadingSpinner.startAnimation(nil)
        loadingOverlay.addSubview(loadingSpinner)

        topBar.material = .hudWindow
        topBar.blendingMode = .withinWindow
        topBar.state = .active
        addSubview(topBar)

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
        topBar.addSubview(backButton)

        reloadButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        reloadButton.bezelStyle = .recessed
        reloadButton.isBordered = false
        reloadButton.target = self
        reloadButton.action = #selector(reloadButtonTapped)
        reloadButton.toolTip = "Reload"
        topBar.addSubview(reloadButton)
    }

    override func layout() {
        super.layout()
        let topBarHeight: CGFloat = 48
        topBar.frame = NSRect(x: 0, y: bounds.height - topBarHeight, width: bounds.width, height: topBarHeight)
        let contentFrame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - topBarHeight))
        webView?.frame = contentFrame
        snapshotImageView.frame = contentFrame
        loadingBlurView.frame = contentFrame
        loadingOverlay.frame = contentFrame
        loadingSpinner.frame = NSRect(
            x: (loadingOverlay.bounds.width - 24) / 2,
            y: (loadingOverlay.bounds.height - 24) / 2,
            width: 24,
            height: 24
        )
        backButton.frame = NSRect(x: 12, y: 8, width: 84, height: 32)
        reloadButton.frame = NSRect(x: topBar.bounds.width - 44, y: 8, width: 32, height: 32)
    }

    func open() {
        if didLoad {
            revealLoadedPage()
            return
        }

        let fallbackURL = URL(string: "https://open.spotify.com/?nd=1")
        guard !didLoad, let url = AppSettings.spotifyWebLastURL ?? fallbackURL else { return }
        open(url)
    }

    func prepareForPresentation() {
        if snapshotImageView.image == nil {
            snapshotImageView.image = loadSnapshotFromDisk()
        }

        presentationReady = false
        pendingRevealAfterPresentation = false
        webView?.isHidden = true
        snapshotImageView.alphaValue = 1
        snapshotImageView.isHidden = snapshotImageView.image == nil
        loadingBlurView.isHidden = true
        loadingOverlay.isHidden = true
        loadingSpinner.stopAnimation(nil)
    }

    func finishPresentation() {
        presentationReady = true

        if pendingRevealAfterPresentation {
            pendingRevealAfterPresentation = false
            revealLoadedPage()
        }
    }

    func capturePreview() {
        guard let webView, !webView.bounds.isEmpty else { return }
        saveCurrentURL(from: webView)
        captureSnapshot(from: webView)
    }

    func open(_ url: URL) {
        let webView = makeWebViewIfNeeded()
        showLoading()
        readinessAttempt = 0
        didLoad = true
        AppSettings.spotifyWebLastURL = url
        webView.load(URLRequest(url: url))
    }

    func close() {
        guard let webView else {
            didLoad = false
            showLoading()
            return
        }

        saveCurrentURL(from: webView)
        captureSnapshotThenDestroy(webView)
        loadingBlurView.isHidden = snapshotImageView.image == nil
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimation(nil)
        didLoad = false
    }

    @objc private func reloadButtonTapped() {
        guard let webView else {
            didLoad = false
            open()
            return
        }

        if webView.url == nil {
            didLoad = false
            open()
        } else {
            readinessAttempt = 0
            showLoading()
            webView.reload()
        }
    }

    @objc private func backButtonTapped() {
        onBack?()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        saveCurrentURL(from: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        saveCurrentURL(from: webView)
        waitForSpotifyReady()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView else { return }
        hideLoading()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView else { return }
        hideLoading()
    }

    private func showLoading() {
        webView?.isHidden = true
        let hasSnapshot = snapshotImageView.image != nil
        snapshotImageView.isHidden = !hasSnapshot
        loadingBlurView.isHidden = !hasSnapshot
        loadingOverlay.layer?.backgroundColor = (hasSnapshot
            ? NSColor.black.withAlphaComponent(0.68)
            : NSColor.black).cgColor
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimation(nil)
    }

    private func hideLoading() {
        revealLoadedPage()
    }

    private func revealLoadedPage() {
        guard presentationReady else {
            pendingRevealAfterPresentation = true
            return
        }

        webView?.isHidden = false
        loadingSpinner.stopAnimation(nil)
        loadingOverlay.isHidden = true
        loadingBlurView.isHidden = true

        guard snapshotImageView.isHidden == false else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            snapshotImageView.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.snapshotImageView.isHidden = true
            self?.snapshotImageView.alphaValue = 1
        }
    }

    private func waitForSpotifyReady() {
        guard let webView else { return }

        readinessAttempt += 1
        webView.evaluateJavaScript(Self.spotifyReadyScript) { [weak self] result, _ in
            guard let self, webView === self.webView else { return }

            if result as? Bool == true || self.readinessAttempt >= 60 {
                self.hideLoading()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.waitForSpotifyReady()
            }
        }
    }

    private func makeWebViewIfNeeded() -> WKWebView {
        if let webView {
            return webView
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.mutePageScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.hideSpotifyControlsScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        let webView = WKWebView(frame: snapshotImageView.frame, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.black.cgColor
        webView.setValue(false, forKey: "drawsBackground")
        webView.isHidden = true
        addSubview(webView, positioned: .below, relativeTo: snapshotImageView)
        self.webView = webView

        return webView
    }

    private func captureSnapshotThenDestroy(_ webView: WKWebView) {
        self.webView = nil
        webView.isHidden = true

        guard !webView.bounds.isEmpty else {
            destroyDetached(webView)
            return
        }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            if let image {
                self?.snapshotImageView.image = image
                self?.snapshotImageView.isHidden = false
                self?.saveSnapshotToDisk(image)
            }
            self?.destroyDetached(webView)
        }
    }

    private func captureSnapshot(from webView: WKWebView) {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let self, let image else { return }
            self.snapshotImageView.image = image
            self.saveSnapshotToDisk(image)
        }
    }

    private func destroyDetached(_ webView: WKWebView) {
        webView.stopLoading()
        webView.loadHTMLString(Self.blankPageHTML, baseURL: nil)
        webView.navigationDelegate = nil
        webView.isHidden = true
        webView.removeFromSuperview()
    }

    private func saveCurrentURL(from webView: WKWebView) {
        guard let url = webView.url else { return }
        AppSettings.spotifyWebLastURL = url
    }

    private func loadSnapshotFromDisk() -> NSImage? {
        NSImage(contentsOf: Self.snapshotFileURL)
    }

    private func saveSnapshotToDisk(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: Self.applicationSupportURL,
                withIntermediateDirectories: true
            )
            try pngData.write(to: Self.snapshotFileURL, options: .atomic)
        } catch {
            AppLogger.error("Failed to save Spotify Web snapshot: \(error)")
        }
    }

    private static var applicationSupportURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("SpotyPopup", isDirectory: true)
    }

    private static var snapshotFileURL: URL {
        applicationSupportURL.appendingPathComponent("spotify-web-preview.png")
    }

    private static let blankPageHTML = """
    <!doctype html><html><head><style>html,body{margin:0;background:#000;color:#fff;}</style></head><body></body></html>
    """

    private static let spotifyReadyScript = """
    (() => {
        const bodyText = (document.body?.innerText || '').trim();
        const hasShell = !!document.querySelector('#main, main, [data-testid="root"], [data-testid="global-nav-bar"], #global-nav-bar');
        const hasPlayer = !!document.querySelector('[data-testid="now-playing-widget"], [data-testid="control-button-playpause"], footer');
        const hasUsefulContent = bodyText.length > 300 || document.querySelectorAll('a[href], button').length > 20;
        return document.readyState === 'complete' && hasShell && (hasPlayer || hasUsefulContent);
    })();
    """

    private static let mutePageScript = """
    (() => {
        const mute = element => {
            if (!element || !('muted' in element)) return;
            element.muted = true;
            element.defaultMuted = true;
            element.volume = 0;
        };

        const muteAll = () => {
            document.querySelectorAll('audio, video').forEach(mute);
        };

        const originalPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function() {
            mute(this);
            return originalPlay.apply(this, arguments);
        };

        document.addEventListener('play', event => mute(event.target), true);
        document.addEventListener('loadedmetadata', event => mute(event.target), true);

        new MutationObserver(mutations => {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (node.nodeType !== Node.ELEMENT_NODE) continue;
                    if (node.matches?.('audio, video')) mute(node);
                    node.querySelectorAll?.('audio, video').forEach(mute);
                }
            }
        }).observe(document.documentElement, { childList: true, subtree: true });

        muteAll();
        setInterval(muteAll, 1000);
    })();
    """

    private static let hideSpotifyControlsScript = """
    (() => {
        const styleId = 'spotypopup-hidden-spotify-controls';
        const hiddenSelector = [
            '#global-nav-bar a[href*="download"]',
            'button[aria-describedby="connect-message-nudge"]',
            'button[data-testid="control-button-connect-to-device"]',
            'button[aria-controls="device-picker"]',
            '#global-nav-bar button[data-testid="friend-activity-button"]',
            '#global-nav-bar button[data-testid="friends-activity-button"]',
            '#global-nav-bar button[data-testid="buddy-feed-button"]'
        ].join(',');

        const installStyle = () => {
            if (document.getElementById(styleId)) return;
            const parent = document.head || document.documentElement;
            if (!parent) return;

            const style = document.createElement('style');
            style.id = styleId;
            style.textContent = `html,body{background:#000!important;}${hiddenSelector}{display:none!important;}`;
            parent.appendChild(style);
        };

        const hideElement = element => {
            if (!element) return;
            element.style.setProperty('display', 'none', 'important');
            element.setAttribute('aria-hidden', 'true');
            element.setAttribute('tabindex', '-1');
        };

        const isInstallLink = anchor => {
            if (!anchor) return false;

            const href = (anchor.getAttribute('href') || '').toLowerCase();
            if (href.includes('download')) return true;

            try {
                return new URL(anchor.href, location.href).pathname.toLowerCase().includes('download');
            } catch (_) {
                return false;
            }
        };

        const hasConnectDeviceIcon = button => {
            const paths = Array.from(button.querySelectorAll('svg path'))
                .map(path => path.getAttribute('d') || '');

            return paths.some(path => path.includes('M2.002 2.75') && path.includes('v11.5')) &&
                paths.some(path => path.includes('M8 6.438'));
        };

        const hasActiveDeviceBannerIcon = element => {
            const paths = Array.from(element.querySelectorAll('svg path'))
                .map(path => path.getAttribute('d') || '');

            return paths.some(path => path.includes('M14.5 8') && path.includes('13.86')) &&
                paths.some(path => path.includes('M11.259 8') && path.includes('l-4.139 2.39'));
        };

        const isConnectDeviceButton = button => {
            if (!button) return false;

            return button.getAttribute('aria-describedby') === 'connect-message-nudge' ||
                button.getAttribute('data-testid') === 'control-button-connect-to-device' ||
                button.getAttribute('aria-controls') === 'device-picker' ||
                hasConnectDeviceIcon(button);
        };

        const isPeopleButton = button => {
            if (!button) return false;

            return [
                'friend-activity-button',
                'friends-activity-button',
                'buddy-feed-button'
            ].includes(button.getAttribute('data-testid')) &&
                !!button.closest('#global-nav-bar');
        };

        const isActiveDeviceBanner = element => {
            if (!element || !element.closest('aside')) return false;
            if (!element.querySelector('button[data-encore-id="textLink"] span[aria-live="polite"]')) return false;

            return hasActiveDeviceBannerIcon(element);
        };

        const hideControls = () => {
            installStyle();
            document.querySelectorAll('#global-nav-bar a[href]').forEach(anchor => {
                if (isInstallLink(anchor)) hideElement(anchor);
            });
            document.querySelectorAll('button').forEach(button => {
                if (isConnectDeviceButton(button) || isPeopleButton(button)) hideElement(button);
            });
            document.querySelectorAll('aside div').forEach(element => {
                if (isActiveDeviceBanner(element)) hideElement(element);
            });
        };

        const start = () => {
            hideControls();

            const target = document.body || document.documentElement;
            if (target) {
                new MutationObserver(hideControls).observe(target, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['href', 'aria-describedby', 'data-testid', 'aria-controls']
                });
            }

            setInterval(hideControls, 1500);
        };

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', start, { once: true });
        } else {
            start();
        }
    })();
    """
}
