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

Use a movie format supported by macOS AVPlayer, such as H.264 video in an MP4 container. PDFs that use Flash or `RichMedia` annotations are not supported by this implementation.

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
