;;; slidepilot-movie.el --- Insert PDF movies with generated posters -*- lexical-binding: t; -*-

;;; Commentary:
;; Load this file and run M-x slidepilot-insert-movie in a saved LaTeX buffer,
;; or M-x slidepilot-insert-movie-url for a web address such as a YouTube page.
;; Requires ffmpeg on `exec-path' and \\usepackage{multimedia} in the preamble.
;;
;; M-x slidepilot-insert-web-page inserts a live, interactive web page
;; (\\webpage from latex/slidepilot.sty) with a snapshot of the page as its
;; poster.  It requires Swift (Xcode or its Command Line Tools) and keeps
;; slidepilot-webpage-snapshot.swift beside this file.
;;
;; Each command can insert a full-screen movie or page, covering the whole
;; slide; see `slidepilot-movie-fullscreen' and `slidepilot-webpage-fullscreen'.
;; Full-screen insertions need \\usepackage{slidepilot} (latex/slidepilot.sty).

;;; Code:

(require 'subr-x)
(require 'url)
(require 'url-parse)

(defgroup slidepilot-movie nil
  "Insert movies for PDF presentations."
  :group 'tex)

(defcustom slidepilot-movie-ffmpeg-program "ffmpeg"
  "FFmpeg executable used to extract the first video frame."
  :type 'string)

(defcustom slidepilot-movie-autostart nil
  "Non-nil means inserted movies start playing when their slide opens.
A prefix argument to `slidepilot-insert-movie' asks instead."
  :type 'boolean)

(defcustom slidepilot-movie-loop nil
  "Non-nil means inserted movies loop until the slide changes.
A prefix argument to `slidepilot-insert-movie' asks instead."
  :type 'boolean)

(defcustom slidepilot-movie-fullscreen nil
  "Non-nil means inserted movies cover the whole slide.
This adds Beamer's \\movie option fullscreen from latex/slidepilot.sty.
A prefix argument to `slidepilot-insert-movie' asks instead."
  :type 'boolean)

(defcustom slidepilot-webpage-fullscreen nil
  "Non-nil means inserted web pages cover the whole slide.
A prefix argument to `slidepilot-insert-web-page' asks instead."
  :type 'boolean)

(defcustom slidepilot-webpage-swift-program "swift"
  "Swift executable that runs the web page snapshot script."
  :type 'string)

(defcustom slidepilot-webpage-size '(1024 . 640)
  "Width and height in CSS pixels at which web pages are laid out.
The snapshot shows this area, and SlidePilot lays the live page out at
the same width, so the two match."
  :type '(cons integer integer))

(defconst slidepilot-webpage--snapshot-script
  (expand-file-name "slidepilot-webpage-snapshot.swift"
                    (file-name-directory (or load-file-name buffer-file-name default-directory)))
  "Swift script that saves a PNG snapshot of a web page.")

(defun slidepilot-insert-movie (movie &optional autostart loop fullscreen)
  "Generate a poster for MOVIE and insert a centered LaTeX movie at point.
Non-nil AUTOSTART adds the autostart option so the movie plays as soon
as its slide is shown.  Non-nil LOOP adds the loop option so the movie
repeats until the slide changes.  Non-nil FULLSCREEN adds the fullscreen
option so the movie covers the whole slide; that needs
\\usepackage{slidepilot}.  Interactively these come from
`slidepilot-movie-autostart', `slidepilot-movie-loop' and
`slidepilot-movie-fullscreen'; with a prefix argument, ask for each.
The poster is named MOVIE's base name followed by -poster.png, beside
MOVIE.  Ask before replacing an existing poster.  Paths are relative
to the current LaTeX file.  Limit the movie to text width and 72 percent
of text height, retaining its aspect ratio so it fits below a slide title.
The buffer must visit a file, but this command does not save the buffer."
  (interactive (cons (read-file-name "Movie file: " nil nil t) (slidepilot-movie--read-options)))
  (unless buffer-file-name
    (user-error "Save the LaTeX buffer to a file first"))
  (unless (executable-find slidepilot-movie-ffmpeg-program)
    (user-error "Cannot find %s; add FFmpeg to exec-path" slidepilot-movie-ffmpeg-program))
  (let* ((movie (expand-file-name movie))
         (base (file-name-directory (expand-file-name buffer-file-name)))
         (poster (concat (file-name-sans-extension movie) "-poster.png"))
         (movie-path (file-relative-name movie base))
         (poster-path (file-relative-name poster base)))
    (when (or (file-remote-p movie) (file-remote-p buffer-file-name))
      (user-error "Movie insertion requires local files"))
    (unless (file-regular-p movie)
      (user-error "Movie is not a regular file: %s" movie))
    ;; Braces break detokenize; parentheses/backslashes break PDF literal strings.
    (when (string-match-p "[{}()\\\\\n\r]" movie-path)
      (user-error "Rename the movie or its folders to remove braces, parentheses or backslashes"))
    (slidepilot-movie--confirm-poster poster)
    (slidepilot-movie--write-poster
     poster (lambda (temporary)
              (slidepilot-movie--ffmpeg-poster movie temporary)))
    (slidepilot-movie--insert poster-path movie-path autostart loop fullscreen)))

(defun slidepilot-insert-movie-url (url &optional autostart loop fullscreen)
  "Generate a poster for the movie at URL and insert a centered LaTeX movie.
URL is an http or https address of a movie file or a YouTube page;
SlidePilot plays YouTube pages in YouTube's embedded player.  The
poster is YouTube's thumbnail, or else the first frame as read by FFmpeg.
It is written beside the LaTeX file, named after the video ID or the
URL's file name, followed by -poster.  AUTOSTART, LOOP and FULLSCREEN are as for
`slidepilot-insert-movie'.  Playing the movie requires a network
connection during the presentation."
  (interactive (cons (string-trim (read-string "Movie URL: ")) (slidepilot-movie--read-options)))
  (unless buffer-file-name
    (user-error "Save the LaTeX buffer to a file first"))
  (unless (string-match-p "\\`https?://[^[:space:]]+\\'" url)
    (user-error "Enter an http or https URL without spaces: %s" url))
  (let* ((video (slidepilot-movie--youtube-id url))
         (name (or video
                   (let ((file (replace-regexp-in-string
                                "\\`-+\\|-+\\'" ""
                                (replace-regexp-in-string
                                 "[^[:alnum:]._-]+" "-"
                                 (file-name-sans-extension
                                  (file-name-nondirectory
                                   (url-unhex-string
                                    (car (url-path-and-query (url-generic-parse-url url))))))))))
                     (if (string-empty-p file) "movie" file))))
         (poster (expand-file-name (concat name "-poster" (if video ".jpg" ".png"))
                                   (file-name-directory (expand-file-name buffer-file-name)))))
    (unless (or video (executable-find slidepilot-movie-ffmpeg-program))
      (user-error "Cannot find %s; add FFmpeg to exec-path" slidepilot-movie-ffmpeg-program))
    (slidepilot-movie--confirm-poster poster)
    (slidepilot-movie--write-poster
     poster (lambda (temporary)
              (if video
                  (condition-case err
                      (url-copy-file (format "https://img.youtube.com/vi/%s/hqdefault.jpg" video) temporary t)
                    (error (user-error "Could not download the YouTube thumbnail: %s"
                                       (error-message-string err))))
                (slidepilot-movie--ffmpeg-poster url temporary))))
    (slidepilot-movie--insert (file-name-nondirectory poster)
                              (slidepilot-movie--pdf-escape url) autostart loop fullscreen)))

(defun slidepilot-insert-web-page (address &optional fullscreen)
  "Snapshot the web page at ADDRESS and insert a centered live web page.
ADDRESS is an http or https URL, or a local HTML file.  SlidePilot shows
the live page on the slide, where you can use it as in a browser; the
snapshot is the poster that other PDF viewers show as a link.  The page
is laid out at `slidepilot-webpage-size'.  Non-nil FULLSCREEN makes the
page cover the whole slide; its snapshot then takes the slide's shape,
from the aspectratio class option (default 4:3), at the same width.
Interactively FULLSCREEN comes from `slidepilot-webpage-fullscreen'; with
a prefix argument, ask.  The poster is written beside
the LaTeX file (beside the HTML file for local pages), named after the
address followed by -poster.png.  Ask before replacing an existing poster.
The preamble needs \\usepackage{slidepilot} and \\usepackage{graphicx}."
  (interactive (list (string-trim (read-string "Web page URL or HTML file: "))
                     (if current-prefix-arg
                         (y-or-n-p "Cover the whole slide? ")
                       slidepilot-webpage-fullscreen)))
  (unless buffer-file-name
    (user-error "Save the LaTeX buffer to a file first"))
  (unless (file-readable-p slidepilot-webpage--snapshot-script)
    (user-error "Cannot find %s" slidepilot-webpage--snapshot-script))
  (unless (executable-find slidepilot-webpage-swift-program)
    (user-error "Cannot find %s; install Xcode or its Command Line Tools" slidepilot-webpage-swift-program))
  (let* ((base (file-name-directory (expand-file-name buffer-file-name)))
         (web (string-match-p "\\`https?://" address))
         (file (unless web (expand-file-name address base)))
         (width (car slidepilot-webpage-size))
         (height (if fullscreen
                     (round (/ width (slidepilot-webpage--slide-aspect)))
                   (cdr slidepilot-webpage-size)))
         poster target)
    (if web
        (progn
          (when (string-match-p "[[:space:]]" address)
            (user-error "Enter a URL without spaces: %s" address))
          (let ((name (replace-regexp-in-string
                       "\\`-+\\|-+\\'" ""
                       (replace-regexp-in-string
                        "[^[:alnum:]]+" "-"
                        (replace-regexp-in-string "\\`https?://\\(?:www\\.\\)?\\|[?#].*\\'" "" address)))))
            (setq poster (expand-file-name (concat (if (string-empty-p name) "webpage" (truncate-string-to-width name 60))
                                                   "-poster.png")
                                           base)
                  target (slidepilot-webpage--latex-url address))))
      (when (or (file-remote-p file) (file-remote-p buffer-file-name))
        (user-error "Web page insertion requires local files"))
      (unless (file-regular-p file)
        (user-error "Not a URL or an existing file: %s" address))
      (setq poster (concat (file-name-sans-extension file) "-poster.png")
            target (file-relative-name file base))
      ;; These would be read as TeX or URL syntax.
      (when (string-match-p "[{}\\^%#\n\r]" target)
        (user-error "Rename the file or its folders to remove braces, backslashes, ^, %% or #")))
    (slidepilot-movie--confirm-poster poster)
    (message "Taking a snapshot of %s..." address)
    (slidepilot-movie--write-poster
     poster (lambda (temporary)
              (with-temp-buffer
                (let ((status (call-process slidepilot-webpage-swift-program nil t nil
                                            slidepilot-webpage--snapshot-script (if web address file)
                                            temporary (number-to-string width) (number-to-string height))))
                  (unless (and (integerp status) (zerop status))
                    (user-error "Could not take a snapshot: %s" (string-trim (buffer-string))))))))
    (let ((options (delq nil (list (and fullscreen "fullscreen")
                                   (and (/= width 1024) (format "pagewidth=%d" width)))))
          (poster-path (file-relative-name poster base)))
      (atomic-change-group
        (insert (if fullscreen
                    (format "\n\\webpage[%s]\n  {\\includegraphics[width=\\paperwidth,height=\\paperheight,keepaspectratio]{\\detokenize{%s}}}\n  {%s}\n"
                            (mapconcat #'identity options ",") poster-path target)
                  (format "\n\\par\n\\begin{center}\n  \\webpage%s\n    {\\includegraphics[width=\\textwidth,height=0.72\\textheight,keepaspectratio]{\\detokenize{%s}}}\n    {%s}\n\\end{center}\n"
                          (if options (format "[%s]" (car options)) "") poster-path target)))))
    (message "Snapshot saved; web page inserted. Preamble needs \\usepackage{slidepilot} and \\usepackage{graphicx}.")))

(defun slidepilot-webpage--slide-aspect ()
  "Width over height of this document's slides.
Use the slide size that latex/slidepilot.sty records in the .aux file of
the master document (`TeX-master' when it names a file), which knows
sizes set by themes.  Before the document has been compiled with it,
read Beamer's aspectratio option from \\documentclass; default 4:3."
  (or (slidepilot-webpage--aux-aspect)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (let ((ratio (and (re-search-forward
                             "\\\\documentclass\\[[^]]*\\baspectratio=\\([0-9]+\\)" nil t)
                            (match-string 1))))
            (unless ratio
              (message "Slide shape unknown until the slides are compiled with slidepilot.sty; assuming 4:3"))
            (pcase ratio
              ("1610" 1.6) ("169" (/ 16.0 9)) ("149" (/ 14.0 9)) ("141" 1.41)
              ("54" 1.25) ("32" 1.5) ("235" 2.35)
              (_ (/ 4.0 3))))))))

(defun slidepilot-webpage--aux-aspect ()
  "Slide width over height recorded in the master document's .aux file, or nil."
  (let* ((master (if (and (boundp 'TeX-master) (stringp TeX-master))
                     (expand-file-name TeX-master (file-name-directory buffer-file-name))
                   buffer-file-name))
         (aux (concat (file-name-sans-extension master) ".aux")))
    (when (and (file-regular-p aux) (file-readable-p aux))
      (with-temp-buffer
        (insert-file-contents aux)
        (when (re-search-forward "^%slidepilot-paper \\([0-9.]+\\) \\([0-9.]+\\)$" nil t)
          (let ((width (string-to-number (match-string 1)))
                (height (string-to-number (match-string 2))))
            (and (> width 0) (> height 0) (/ width height))))))))

(defun slidepilot-movie--read-options ()
  "Return (AUTOSTART LOOP FULLSCREEN) from the user options.
With a prefix argument, ask for each instead."
  (if current-prefix-arg
      (list (y-or-n-p "Start when the slide opens? ")
            (y-or-n-p "Loop until the slide changes? ")
            (y-or-n-p "Cover the whole slide? "))
    (list slidepilot-movie-autostart slidepilot-movie-loop slidepilot-movie-fullscreen)))

(defun slidepilot-webpage--latex-url (url)
  "Write URL for the URL argument of \\webpage.
Characters TeX cannot take in an argument are percent-encoded, then
# and % are written \\# and \\%."
  (replace-regexp-in-string
   "[#%]" (lambda (char) (concat "\\" char))
   (replace-regexp-in-string "[{}\\^]"
                             (lambda (char) (format "%%%02X" (string-to-char char)))
                             url t t)
   t t))

(defun slidepilot-movie--youtube-id (url)
  "Return the YouTube video ID in URL, or nil."
  (when (string-match (concat "\\`https?://\\(?:www\\.\\|m\\.\\)?"
                              "\\(?:youtu\\.be/\\|youtube\\.com/\\(?:watch\\?\\(?:[^#]*&\\)?v=\\|embed/\\|shorts/\\|live/\\)\\)"
                              "\\([[:alnum:]_-]\\{11\\}\\)\\(?:[?&#/]\\|\\'\\)")
                      url)
    (match-string 1 url)))

(defun slidepilot-movie--pdf-escape (url)
  "Write characters of URL that TeX or PDF strings mishandle as PDF octal escapes.
\\detokenize keeps the backslash, and the PDF reader decodes the escape."
  (replace-regexp-in-string "[][%#(){}\\^~]"
                            (lambda (char) (format "\\%03o" (string-to-char char)))
                            url t t))

(defun slidepilot-movie--confirm-poster (poster)
  "Ask before replacing an existing POSTER."
  (when (and (file-exists-p poster)
             (not (y-or-n-p (format "Replace poster %s? " poster))))
    (user-error "Cancelled; poster and buffer unchanged")))

(defun slidepilot-movie--write-poster (poster writer)
  "Call WRITER with a temporary file, then move it to POSTER if not empty."
  (let ((temporary (make-temp-file (expand-file-name ".slidepilot-poster-" (file-name-directory poster))
                                   nil (concat "." (file-name-extension poster)))))
    (unwind-protect
        (progn
          (funcall writer temporary)
          (unless (> (or (file-attribute-size (file-attributes temporary)) 0) 0)
            (user-error "Could not generate a poster"))
          (rename-file temporary poster t))
      (when (file-exists-p temporary) (delete-file temporary)))))

(defun slidepilot-movie--ffmpeg-poster (movie output)
  "Write MOVIE's first video frame to OUTPUT with FFmpeg."
  (with-temp-buffer
    (let ((status (call-process slidepilot-movie-ffmpeg-program nil t nil
                                "-nostdin" "-hide_banner" "-loglevel" "error" "-y"
                                "-i" movie "-map" "0:v:0" "-frames:v" "1" output)))
      (unless (and (integerp status) (zerop status)
                   (> (file-attribute-size (file-attributes output)) 0))
        (user-error "FFmpeg could not generate a poster: %s" (buffer-string))))))

(defun slidepilot-movie--insert (poster-path movie-path autostart loop &optional fullscreen)
  "Insert a movie showing POSTER-PATH and playing MOVIE-PATH.
The movie is centered below the slide title, or with FULLSCREEN covers
the whole slide."
  (let* ((options (delq nil (list (and autostart "autostart") (and loop "loop")
                                  (and fullscreen "fullscreen"))))
         (options (if options (format "[%s]" (mapconcat #'identity options ",")) "")))
    (atomic-change-group
      (insert (if fullscreen
                  (format "\n\\movie%s\n  {\\includegraphics[width=\\paperwidth,height=\\paperheight,keepaspectratio]{\\detokenize{%s}}}\n  {\\detokenize{%s}}\n"
                          options poster-path movie-path)
                (format "\n\\par\n\\begin{center}\n  \\movie%s\n    {\\includegraphics[width=\\textwidth,height=0.72\\textheight,keepaspectratio]{\\detokenize{%s}}}\n    {\\detokenize{%s}}\n\\end{center}\n"
                        options poster-path movie-path)))))
  (message "Poster created; movie inserted. Preamble needs \\usepackage{multimedia}%s and \\usepackage{graphicx}."
           (if fullscreen ", \\usepackage{slidepilot}" "")))

(provide 'slidepilot-movie)
;;; slidepilot-movie.el ends here
