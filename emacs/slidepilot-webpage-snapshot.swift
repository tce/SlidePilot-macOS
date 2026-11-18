// Saves a PNG snapshot of a web page, for use as a \webpage poster.
//
//   swift slidepilot-webpage-snapshot.swift <url> <output.png> [width] [height]
//
// The page is laid out width by height CSS pixels (default 1024 by 640), the
// same layout SlidePilot uses for \webpage[pagewidth=width]. The snapshot is
// taken a moment after the page finishes loading so scripts can render.
import Cocoa
import WebKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write("usage: slidepilot-webpage-snapshot <url> <output.png> [width] [height]\n".data(using: .utf8)!)
    exit(64)
}
let address = arguments[1]
let output = URL(fileURLWithPath: arguments[2])
let width = arguments.count > 3 ? Double(arguments[3]) ?? 1024 : 1024
let height = arguments.count > 4 ? Double(arguments[4]) ?? 640 : 640
let url: URL = {
    if let url = URL(string: address), let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) { return url }
    return URL(fileURLWithPath: address)
}()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("slidepilot-webpage-snapshot: \(message)\n".data(using: .utf8)!)
    exit(1)
}

final class Snapshotter: NSObject, WKNavigationDelegate {
    let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: width, height: height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    var finished = false

    func start() {
        window.contentView = webView
        window.orderBack(nil)
        webView.navigationDelegate = self
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { fail("timed out loading \(address)") }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !finished else { return }
        finished = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.snapshot() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error.localizedDescription)
    }

    func snapshot() {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        configuration.snapshotWidth = NSNumber(value: width)  // points; Retina screens double the pixels
        webView.takeSnapshot(with: configuration) { image, error in
            guard let image = image, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                fail(error?.localizedDescription ?? "could not render a snapshot")
            }
            do { try png.write(to: output, options: .atomic) } catch { fail(error.localizedDescription) }
            exit(0)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let snapshotter = Snapshotter()
snapshotter.start()
app.run()
