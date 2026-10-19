//
//  WebMoviePlayer.swift
//  SlidePilot
//

import Cocoa
import WebKit

/// Plays a YouTube movie with YouTube's embedded player. Every window keeps its
/// controls, and playing, pausing or seeking in one is mirrored by the others.
/// Only the leader plays audio, autostarts and loops, so connected windows show
/// the same movie without doubling the sound.
final class WebMoviePlayer: WKWebView, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

    private static let stateChangedNotification = Notification.Name("WebMoviePlayerStateChanged")
    /// The latest state of each video, for players that load after it changes.
    private static var latestStates = [String: (playing: Bool, time: Double, date: Date)]()
    /// YouTube refuses embeds without an HTTP origin, so the page uses this one.
    private static let origin = URL(string: "https://slidepilotapp.com/")!

    let videoID: String
    let isLeader: Bool
    private let autostart: Bool
    private let loop: Bool
    private var isReady = false
    /// A state requested by another player; its echo must not be sent back.
    private var expectedState: (playing: Bool, until: Date)?

    init(videoID: String, isLeader: Bool, autostart: Bool, loop: Bool, controls: Bool) {
        self.videoID = videoID
        self.isLeader = isLeader
        self.autostart = autostart
        self.loop = loop
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        super.init(frame: .zero, configuration: configuration)
        configuration.userContentController.add(WeakMessageHandler(self), name: "slidePilot")
        navigationDelegate = self
        uiDelegate = self
        setValue(false, forKey: "drawsBackground")
        if isLeader { Self.latestStates[videoID] = nil }
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged(_:)),
                                               name: Self.stateChangedNotification, object: nil)
        loadHTMLString(Self.html(videoID: videoID, controls: controls, muted: !isLeader),
                       baseURL: Self.origin)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Stops playback and releases the page. Call when the slide changes.
    func stop() {
        NotificationCenter.default.removeObserver(self)
        configuration.userContentController.removeScriptMessageHandler(forName: "slidePilot")
        if isLeader { Self.latestStates[videoID] = nil }
        loadHTMLString("", baseURL: nil)
    }

    // MARK: - Player Page

    private static func html(videoID: String, controls: Bool, muted: Bool) -> String {
        let originString = origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <style>html, body, #player { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }</style>
        </head><body><div id="player"></div>
        <script>
        var player;
        function post(message) { window.webkit.messageHandlers.slidePilot.postMessage(message); }
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            width: '100%', height: '100%', videoId: '\(videoID)',
            playerVars: { controls: \(controls ? 1 : 0), disablekb: \(controls ? 0 : 1), playsinline: 1, rel: 0, origin: '\(originString)' },
            events: {
              onReady: function () { \(muted ? "player.mute();" : "") post({ event: 'ready' }); },
              onStateChange: function (e) { post({ event: 'state', state: e.data, time: player.getCurrentTime() }); },
              onError: function (e) { post({ event: 'error', code: e.data }); }
            }
          });
        }
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }

    private func run(_ script: String) {
        evaluateJavaScript("if (player) { \(script) }", completionHandler: nil)
    }

    private func apply(playing: Bool, time: Double) {
        expectedState = (playing, Date().addingTimeInterval(2))
        run("if (Math.abs(player.getCurrentTime() - \(time)) > 1) { player.seekTo(\(time), true); }")
        run(playing ? "player.playVideo();" : "player.pauseVideo();")
    }

    // MARK: - Messages

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
        switch event {
        case "ready":
            isReady = true
            // Join playback another window already started, else autostart.
            if let state = Self.latestStates[videoID] {
                apply(playing: state.playing, time: state.time + (state.playing ? Date().timeIntervalSince(state.date) : 0))
            } else if isLeader && autostart {
                run("player.playVideo();")
            }
        case "state":
            guard let state = body["state"] as? Int else { return }
            let time = body["time"] as? Double ?? 0
            // YouTube states: 0 ended, 1 playing, 2 paused. Ignore buffering and cueing.
            if state == 0 && loop {
                if isLeader { run("player.seekTo(0, true); player.playVideo();") }
                return
            }
            guard [0, 1, 2].contains(state) else { return }
            if let expected = expectedState, Date() < expected.until {
                // Reaching the requested state is an echo; anything else is the user.
                if expected.playing == (state == 1) { expectedState = nil; return }
            }
            expectedState = nil
            Self.latestStates[videoID] = (state == 1, time, Date())
            NotificationCenter.default.post(name: Self.stateChangedNotification, object: self,
                                            userInfo: ["videoID": videoID, "playing": state == 1, "time": time])
        case "error":
            NSLog("YouTube player error %@ for video %@", String(describing: body["code"] ?? ""), videoID)
        default:
            break
        }
    }

    @objc private func stateChanged(_ notification: Notification) {
        guard isReady, notification.object as AnyObject? !== self, notification.userInfo?["videoID"] as? String == videoID,
              let playing = notification.userInfo?["playing"] as? Bool,
              let time = notification.userInfo?["time"] as? Double else { return }
        apply(playing: playing, time: time)
    }

    // MARK: - Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Keep the slide on the player; links such as the YouTube logo open in the browser.
        if navigationAction.navigationType == .linkActivated, navigationAction.targetFrame?.isMainFrame != false,
           let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }
}

/// WKUserContentController retains its handlers; this breaks the cycle.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
