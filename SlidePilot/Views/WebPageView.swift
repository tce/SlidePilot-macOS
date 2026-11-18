//
//  WebPageView.swift
//  SlidePilot
//

import Cocoa
import WebKit

/// A live web page placed on a slide with `\webpage` (latex/slidepilot.sty).
/// It behaves like a browser tab: click, scroll, type and follow links.
/// Presenter and audience windows each show the page; whichever one you use
/// leads, and the others follow its address and scroll position. Only the
/// leader plays sound, so media in the page is not heard twice.
final class WebPageView: WKWebView, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

    private static let changedNotification = Notification.Name("WebPageViewChanged")
    /// The latest address and scroll position of each page, so a window that
    /// loads later joins where the others are.
    private static var latestStates = [String: (url: URL, scroll: [Double]?)]()
    /// The view the user last clicked, scrolled or typed in. Only it reports
    /// changes, so views following each other cannot echo or loop redirects.
    private static weak var active: WebPageView?

    /// Pairs views showing the same `\webpage` in different windows.
    let key: String
    let isLeader: Bool
    private let pageWidth: CGFloat
    /// True while a text field in the page has focus; slide keys then go to the page.
    private(set) var isEditingText = false
    private var urlObservation: NSKeyValueObservation?

    init(url: URL, pageWidth: CGFloat, isLeader: Bool) {
        key = url.absoluteString
        self.isLeader = isLeader
        self.pageWidth = pageWidth
        let configuration = WKWebViewConfiguration()
        let controller = configuration.userContentController
        controller.addUserScript(WKUserScript(source: Self.pageScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        if !isLeader {
            controller.addUserScript(WKUserScript(source: Self.muteScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        super.init(frame: .zero, configuration: configuration)
        controller.add(WeakMessageHandler(self), name: "slidePilotPage")
        navigationDelegate = self
        uiDelegate = self
        allowsBackForwardNavigationGestures = true
        if isLeader { Self.latestStates[key] = nil }
        NotificationCenter.default.addObserver(self, selector: #selector(otherChanged(_:)),
                                               name: Self.changedNotification, object: nil)
        // Covers link clicks, history and in-page (pushState) address changes.
        urlObservation = observe(\.url, options: [.new]) { view, _ in view.addressChanged() }
        open(Self.latestStates[key]?.url ?? url)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Releases the page. Call when the slide changes.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        urlObservation?.invalidate()
        urlObservation = nil
        configuration.userContentController.removeScriptMessageHandler(forName: "slidePilotPage")
        if Self.active === self { Self.active = nil }
        if isLeader { Self.latestStates[key] = nil }
        stopLoading()
        loadHTMLString("", baseURL: nil)
    }

    private func open(_ url: URL) {
        if url.isFileURL {
            loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            load(URLRequest(url: url))
        }
    }

    // MARK: - Layout

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Lay the page out at a fixed width in every window so they match.
        if pageWidth > 0, newSize.width > 0 {
            pageZoom = min(max(newSize.width / pageWidth, 0.1), 10)
        }
    }

    // MARK: - Leading

    override func mouseDown(with event: NSEvent) {
        Self.active = self
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        Self.active = self
        super.rightMouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        Self.active = self
        super.scrollWheel(with: event)
    }

    override func keyDown(with event: NSEvent) {
        Self.active = self
        super.keyDown(with: event)
    }

    private func publish(url: URL, scroll: [Double]?) {
        Self.latestStates[key] = (url, scroll)
        NotificationCenter.default.post(name: Self.changedNotification, object: self, userInfo: ["key": key])
    }

    private func addressChanged() {
        guard Self.active === self, let url = url, url != Self.latestStates[key]?.url,
              ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") else { return }
        publish(url: url, scroll: nil)
    }

    @objc private func otherChanged(_ notification: Notification) {
        guard notification.object as AnyObject? !== self,
              notification.userInfo?["key"] as? String == key,
              let state = Self.latestStates[key] else { return }
        if url != state.url {
            open(state.url)  // didFinish applies the scroll position
        } else if let scroll = state.scroll {
            applyScroll(scroll)
        }
    }

    private func applyScroll(_ scroll: [Double]) {
        let arguments = scroll.map { String($0) }.joined(separator: ", ")
        evaluateJavaScript("window.__slidePilotScroll && window.__slidePilotScroll(\(arguments));", completionHandler: nil)
    }

    // MARK: - Page Scripts

    /// Reports scroll positions and whether a text field has focus. Pages laid
    /// out at the same width scroll to the same offset; others scroll to the
    /// same fraction of their scrollable range.
    private static let pageScript = """
    (function () {
      if (window.__slidePilotScroll) { return; }
      function post(message) { window.webkit.messageHandlers.slidePilotPage.postMessage(message); }
      function range() {
        var e = document.scrollingElement || document.documentElement;
        return { x: Math.max(1, e.scrollWidth - window.innerWidth), y: Math.max(1, e.scrollHeight - window.innerHeight) };
      }
      window.__slidePilotScroll = function (left, top, width, fx, fy) {
        if (Math.abs(window.innerWidth - width) < 2) { window.scrollTo(left, top); return; }
        var r = range();
        window.scrollTo(Math.round(fx * r.x), Math.round(fy * r.y));
      };
      var pending = false;
      window.addEventListener('scroll', function () {
        if (pending) { return; }
        pending = true;
        window.requestAnimationFrame(function () {
          pending = false;
          var r = range();
          post({ event: 'scroll', position: [window.scrollX, window.scrollY, window.innerWidth,
                                              window.scrollX / r.x, window.scrollY / r.y] });
        });
      }, { passive: true });
      function editing() {
        var a = document.activeElement;
        if (!a) { return false; }
        if (a.isContentEditable || a.tagName === 'TEXTAREA' || a.tagName === 'SELECT') { return true; }
        return a.tagName === 'INPUT' && !/^(button|checkbox|radio|submit|reset|image|range|color|file)$/i.test(a.type);
      }
      document.addEventListener('focusin', function () { post({ event: 'editing', value: editing() }); }, true);
      document.addEventListener('focusout', function () {
        setTimeout(function () { post({ event: 'editing', value: editing() }); }, 0);
      }, true);
    })();
    """

    /// Silences media in following windows.
    private static let muteScript = """
    document.addEventListener('play', function (e) { e.target.muted = true; }, true);
    """

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
        switch event {
        case "scroll":
            guard Self.active === self, let url = url,
                  let position = (body["position"] as? [NSNumber])?.map({ $0.doubleValue }), position.count == 5 else { return }
            publish(url: url, scroll: position)
        case "editing":
            isEditingText = body["value"] as? Bool ?? false
        default:
            break
        }
    }

    // MARK: - Navigation

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if Self.active !== self, let state = Self.latestStates[key], state.url == url, let scroll = state.scroll {
            applyScroll(scroll)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Hand mailto:, app links and the like to macOS.
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
           !["http", "https", "file", "about", "data", "blob"].contains(scheme) {
            if Self.active === self || (Self.active == nil && isLeader) { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Open links meant for a new tab or window on the slide.
        load(navigationAction.request)
        return nil
    }

    /// Only one window answers dialogs: the one in use, else the leader.
    private var showsDialogs: Bool { Self.active === self || (Self.active == nil && isLeader) }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard showsDialogs else { completionHandler(); return }
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard showsDialogs else { completionHandler(false); return }
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
}
