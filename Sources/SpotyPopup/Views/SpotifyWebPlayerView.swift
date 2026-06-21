import AppKit
import WebKit

final class SpotifyWebPlayerView: NSView {
    private let topBar = NSVisualEffectView()
    private let webView: WKWebView
    private let backButton = NSButton()
    private let reloadButton = NSButton()
    private var didLoad = false

    var onBack: (() -> Void)?

    override init(frame: NSRect) {
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

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        close()
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        addSubview(webView)

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
        webView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - topBarHeight))
        backButton.frame = NSRect(x: 12, y: 8, width: 84, height: 32)
        reloadButton.frame = NSRect(x: topBar.bounds.width - 44, y: 8, width: 32, height: 32)
    }

    func open() {
        guard !didLoad, let url = URL(string: "https://open.spotify.com/?nd=1") else { return }
        open(url)
    }

    func open(_ url: URL) {
        didLoad = true
        webView.load(URLRequest(url: url))
    }

    func close() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        didLoad = false
    }

    @objc private func reloadButtonTapped() {
        if webView.url == nil {
            didLoad = false
            open()
        } else {
            webView.reload()
        }
    }

    @objc private func backButtonTapped() {
        onBack?()
    }

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
            style.textContent = `${hiddenSelector}{display:none!important;}`;
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
