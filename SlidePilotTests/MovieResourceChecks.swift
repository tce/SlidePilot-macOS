// Standalone integration checks; see MovieFixtures/README.md.
import Foundation
import PDFKit
@main
struct MovieResourceChecks {
static func main() {
let fixtureDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let linked = PDFDocument(url: URL(fileURLWithPath: fixtureDirectory.appendingPathComponent("linked-movie.pdf").path))!
let resources = linked.page(at: 0)!.movieResources()
precondition(resources.count == 2)
precondition(resources[0].bounds == CGRect(x: 10, y: 20, width: 100, height: 100))
let linkedURL = PDFMovieFiles.shared.url(for: resources[0].file, document: linked)!
precondition(linkedURL == fixtureDirectory.appendingPathComponent("movie with spaces.mp4"))
let embedded = PDFDocument(url: URL(fileURLWithPath: fixtureDirectory.appendingPathComponent("embedded-movie.pdf").path))!
let movie = embedded.page(at: 0)!.movieResources()[0]
let first = PDFMovieFiles.shared.url(for: movie.file, document: embedded)!
let second = PDFMovieFiles.shared.url(for: movie.file, document: embedded)!
precondition(first == second)
precondition(try! Data(contentsOf: first) == Data("movie-bytes".utf8))
precondition(!resources.contains(where: { $0.autostart || $0.loop }))
let beamer = PDFDocument(url: fixtureDirectory.appendingPathComponent("autostart-movie.pdf"))!
let options = beamer.page(at: 0)!.movieResources()
precondition(options.map { $0.autostart } == [true, false, false])
precondition(options.map { $0.loop } == [true, true, false])
_ = PDFMovieFiles.shared.url(for: resources[0].file, document: linked)
precondition(!FileManager.default.fileExists(atPath: first.path))
let web = PDFDocument(url: fixtureDirectory.appendingPathComponent("url-movie.pdf"))!
let webMovies = web.page(at: 0)!.movieResources()
let youTube = PDFMovieFiles.shared.url(for: webMovies[0].file, document: web)!
precondition(youTube == URL(string: "https://www.youtube.com/watch?v=P25BwtepmUk")!)
precondition(youTube.youTubeVideoID == "P25BwtepmUk" && webMovies[0].autostart && webMovies[0].loop)
let direct = PDFMovieFiles.shared.url(for: webMovies[1].file, document: web)!
precondition(direct == URL(string: "https://example.com/clip.mp4")! && direct.youTubeVideoID == nil)
for address in ["https://youtu.be/P25BwtepmUk?t=3", "https://m.youtube.com/watch?feature=share&v=P25BwtepmUk",
                "https://www.youtube.com/embed/P25BwtepmUk", "https://youtube.com/shorts/P25BwtepmUk"] {
    precondition(URL(string: address)!.youTubeVideoID == "P25BwtepmUk", address)
}
precondition(URL(string: "https://www.youtube.com/watch?v=short")!.youTubeVideoID == nil)
precondition(URL(string: "https://notyoutube.com/watch?v=P25BwtepmUk")!.youTubeVideoID == nil)
let pages = PDFDocument(url: fixtureDirectory.appendingPathComponent("web-page.pdf"))!
let webPages = pages.page(at: 0)!.webPageResources()
precondition(webPages.count == 2 && pages.page(at: 0)!.movieResources().isEmpty)
// 200pt by 100pt in TeX points are 199.26bp by 99.63bp in PDF units.
precondition(abs(webPages[0].bounds.width - 199.26) < 0.1 && abs(webPages[0].bounds.height - 99.63) < 0.1 && webPages[0].pageWidth == 1024 && webPages[1].pageWidth == 0)
precondition(PDFMovieFiles.shared.url(for: webPages[0].address, document: pages)! == URL(string: "https://example.com/search?q=a%20b&x=1#top")!)
precondition(PDFMovieFiles.shared.url(for: webPages[1].address, document: pages)! == fixtureDirectory.appendingPathComponent("demo page.html"))
precondition(linked.page(at: 0)!.webPageResources().isEmpty)
print("Passed: annotation discovery, bounds, linked filenames, embedded extraction, shared URLs, cleanup, autostart, loop, web URLs, YouTube IDs, web pages")

}
}
