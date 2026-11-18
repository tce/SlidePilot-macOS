# Fork of SlidePilot for macOS
I created this fork of the SlidePilot project so that I could have a PDF player for LaTeX Beamer slides that could also play movies. The code for doing this looks like this:

```
\begin{frame}{OZ for Ground Robots}

\par
\begin{center}
  \movie[autostart,loop]
    {\includegraphics[width=\textwidth,height=0.72\textheight,keepaspectratio]{\detokenize{movies/AOA-GroundRobotInterface-poster.png}}}
    {\detokenize{movies/AOA-GroundRobotInterface.mov}}
\end{center}

\end{frame}
```
The "includegraphics" part gets the size of the movie so pdflatex can compute how to fit it.  The macros in the "emacs" folder show how to do this, and for emacs users, provides an nice macro for inserting a movie.


# SlidePilot for macOS

<p align="center">
  <img width=120 src="https://slidepilotapp.com/img/appicon.svg"/>
</p>
<p align="center">
  <strong>PDF Presentation Tool for macOS, perfect for LaTex Beamer presentations 🖥</strong>
</p>

This is the issue, feature and feedback tracking repository for SlidePilot on macOS. 
This is the source code of the SlidePilot app. If you want to report bugs, improvements, feature requests or anything else, feel free to open a new issue.

Feel free to contribute to this app. When contributing, please be aware that this repository uses the **git flow** pattern.

## Download
SlidePilot for macOS is available on [slidepilotapp.com](https://www.slidepilotapp.com/?utm_source=GitHub&utm_medium=Social&utm_campaign=Static)

## Movies in PDF slides

SlidePilot plays PDF `Movie` annotations directly on the slide using native playback controls. Movies may reference a file beside the PDF (including filenames with spaces), an absolute file path, an HTTP(S) URL, or an embedded file specification. Presenter and audience views share playback. Changing slides stops the previous movie. A movie inserted with Beamer's `\movie[autostart]{poster}{file}` (from the `multimedia` package) starts playing as soon as its slide is shown. Add `loop` (or `repeat`) to replay the movie until you leave the slide, e.g. `\movie[autostart,loop]{poster}{file}`.

A movie may also be a web address: `\movie{poster}{https://example.com/clip.mp4}` streams a movie file (including HLS `.m3u8` streams), and a YouTube page such as `\movie[autostart]{poster}{https://www.youtube.com/watch?v=P25BwtepmUk}` plays in YouTube's embedded player. Both views keep YouTube's controls, and playing, pausing or seeking in either is mirrored in the other; only the presenter view plays audio, so the sound plays once. Web movies need a network connection during the talk, and YouTube videos whose owners disable embedding cannot be played. In Emacs, `M-x slidepilot-insert-movie-url` inserts a web movie, using YouTube's thumbnail or the movie's first frame as the poster.

To make a movie fill the whole slide, add `\usepackage{slidepilot}` (from `latex/`) and the `fullscreen` option: `\movie[autostart,fullscreen]{\includegraphics[width=\paperwidth,height=\paperheight,keepaspectratio]{poster.png}}{movie.mp4}`. The movie covers the slide edge to edge, title included, wherever `\movie` appears in the frame. The movie keeps its aspect ratio, with black bars if its shape differs from the slide's. This works with web movies too, and needs pdfLaTeX or LuaLaTeX (Beamer's `multimedia` package does not support XeLaTeX).

Use a movie format supported by macOS AVPlayer, such as H.264 video in an MP4 container. PDFs that use Flash or `RichMedia` annotations are not supported by this implementation.

## Live web pages in PDF slides

`latex/slidepilot.sty` adds `\webpage[options]{poster}{url}`, which shows a live web page on the slide. While the slide is current, SlidePilot loads the page in the poster's area. You can click, scroll, type and follow links as in a browser. Other PDF viewers show the poster as a link that opens the page in a browser.

```
\usepackage{slidepilot}   % put latex/slidepilot.sty beside your .tex file or on TEXINPUTS
...
\begin{frame}{Live demo}
  \begin{center}
    \webpage{\includegraphics[width=\textwidth,height=0.72\textheight,keepaspectratio]{site-screenshot.png}}
            {https://example.com/search?q=beamer\#results}
  \end{center}
\end{frame}
```

In Emacs, `M-x slidepilot-insert-web-page` asks for a URL or local HTML file, saves a snapshot of the page beside your `.tex` file as the poster, and inserts the `\webpage` lines. It needs Swift (Xcode or its Command Line Tools), and the first snapshot takes several seconds while Swift compiles the snapshot script. `slidepilot-webpage-size` sets the layout size (default 1024×640). The command writes `pagewidth` to match when you change it. To make the page cover the whole slide, set `slidepilot-webpage-fullscreen`, or answer yes when the command asks (it asks when you give it a prefix argument, `C-u`). The snapshot then takes your slides' shape, read from `aspectratio=` in `\documentclass`. The movie commands do the same with `slidepilot-movie-fullscreen`; with `C-u` they ask about autostart, loop and full screen.

The poster's size is the page's size on the slide. Leave the poster empty (`\webpage[width=\textwidth,height=0.7\textheight]{}{url}`) for a framed placeholder. The URL may be an http(s) address or a local HTML file relative to the PDF. Inside a frame, write `#` and `%` as `\#` and `\%`. By default the page is laid out 1024 CSS pixels wide and scaled to fit, so it looks the same in every window. Use `pagewidth=1280` for a wider layout, or `pagewidth=0` to lay the page out at the area's own size. The package works with pdfLaTeX, LuaLaTeX and XeLaTeX.

Add `fullscreen` to make the page cover the whole slide, edge to edge, wherever `\webpage` appears in the frame. It takes no room in the frame, and its poster is drawn over everything else on the slide, title included:

```
\begin{frame}
  \webpage[fullscreen]{\includegraphics[width=\paperwidth,height=\paperheight]{site-screenshot.png}}
          {https://example.com}
\end{frame}
```

With an empty poster, `fullscreen` shows a full-slide placeholder. It needs LaTeX 2020-10 or newer, and allows one full-screen web page or movie per slide.

Presenter and audience views each show the page. The window you click, scroll or type in leads, and the other window follows its address and scroll position. Other page state, such as typed text, menus or the state of a web app, appears only in the window you use. Only the presenter view plays sound. Arrow and Page Up/Down keys still change slides unless a text field in the page has focus. Scroll with the trackpad, mouse or space bar. Links that open a new window open on the slide instead. Pages need a network connection during the talk. Plain `http://` sites are allowed.

## Contribution
Please read the [contribution guidlines](CONTRIBUTING.md) before contributing to the code.

## Links
- [Documentation](https://slidepilot.gitbook.io/slidepilot/)
- [Features & Changelog](https://slidepilot.gitbook.io/slidepilot/changelog)
- [Release Plan](https://slidepilot.gitbook.io/slidepilot/release-plan)

## FAQ

* **What is SlidePilot?**
> SlidePilot was developed for great presentation of LaTex generated presentation PDFs on macOS, especially for the Beamer class. But SlidePilot works great with other PDF presentations as well.

* **How do I report a bug?**
> If you've found a bug, we are more than happy if you report it.
> You can do so by opening an issue in this repository or by writing an email.

* **Can I request new features?**
> Of course! New ideas which improve SlidePilot are always welcome. Feel free to open an issue in this repository or shoot us an [email](mailto:SlidePilot<info@slidepilotapp.com>).

* **How can I stay up to date?**
> If you want to know the latest news about SlidePilot, subscribe to our [newsletter](https://slidepilotapp.us8.list-manage.com/subscribe/post?u=b76c3249644cb91c7a2e50596&id=049e8f25ef).

## Build a standalone macOS app

Open `SlidePilot.xcodeproj`, select the **SlidePilot Standalone** scheme and **My Mac**, then choose **Product → Build**. The scheme builds the existing SlidePilot application with movie support using Release settings and local ad hoc signing; no Apple developer account is required. Find `SlidePilot.app` under Products and use **Show in Finder** to copy it.

For a predictable output location, run:

```sh
bash scripts/build-standalone.sh
```

The finished bundle is `dist/SlidePilot.app`. Copy it to Applications and launch it directly. The application targets macOS 12 or newer. Local ad hoc signing uses an app-specific library-validation exception to load the bundled Sparkle framework without a Team ID. It is for running your own build; distributing a notarized app requires Developer ID signing. The separate `SlidePilot-Movie` starter target is not part of this build.
