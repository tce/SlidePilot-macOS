;;; slidepilot-movie.el --- Insert PDF movies with generated posters -*- lexical-binding: t; -*-

;;; Commentary:
;; Load this file and run M-x slidepilot-insert-movie in a saved LaTeX buffer,
;; or M-x slidepilot-insert-movie-url for a web address such as a YouTube page.
;; Requires ffmpeg on `exec-path' and \\usepackage{multimedia} in the preamble.

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

(defun slidepilot-insert-movie (movie &optional autostart loop)
  "Generate a poster for MOVIE and insert a centered LaTeX movie at point.
Non-nil AUTOSTART adds the autostart option so the movie plays as soon
as its slide is shown.  Non-nil LOOP adds the loop option so the movie
repeats until the slide changes.  Interactively these come from
`slidepilot-movie-autostart' and `slidepilot-movie-loop'; with a prefix
argument, ask for each.
The poster is named MOVIE's base name followed by -poster.png, beside
MOVIE.  Ask before replacing an existing poster.  Paths are relative
to the current LaTeX file.  Limit the movie to text width and 72 percent
of text height, retaining its aspect ratio so it fits below a slide title.
The buffer must visit a file, but this command does not save the buffer."
  (interactive (let ((movie (read-file-name "Movie file: " nil nil t)))
                 (if current-prefix-arg
                     (list movie (y-or-n-p "Start when the slide opens? ")
                           (y-or-n-p "Loop until the slide changes? "))
                   (list movie slidepilot-movie-autostart slidepilot-movie-loop))))
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
    (slidepilot-movie--insert poster-path movie-path autostart loop)))

(defun slidepilot-insert-movie-url (url &optional autostart loop)
  "Generate a poster for the movie at URL and insert a centered LaTeX movie.
URL is an http or https address of a movie file or a YouTube page;
SlidePilot plays YouTube pages in YouTube's embedded player.  The
poster is YouTube's thumbnail, or else the first frame as read by FFmpeg.
It is written beside the LaTeX file, named after the video ID or the
URL's file name, followed by -poster.  AUTOSTART and LOOP are as for
`slidepilot-insert-movie'.  Playing the movie requires a network
connection during the presentation."
  (interactive (let ((url (string-trim (read-string "Movie URL: "))))
                 (if current-prefix-arg
                     (list url (y-or-n-p "Start when the slide opens? ")
                           (y-or-n-p "Loop until the slide changes? "))
                   (list url slidepilot-movie-autostart slidepilot-movie-loop))))
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
                              (slidepilot-movie--pdf-escape url) autostart loop)))

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

(defun slidepilot-movie--insert (poster-path movie-path autostart loop)
  "Insert a centered movie showing POSTER-PATH and playing MOVIE-PATH."
  (atomic-change-group
    (insert (format "\n\\par\n\\begin{center}\n  \\movie%s\n    {\\includegraphics[width=\\textwidth,height=0.72\\textheight,keepaspectratio]{\\detokenize{%s}}}\n    {\\detokenize{%s}}\n\\end{center}\n"
                    (let ((options (delq nil (list (and autostart "autostart") (and loop "loop")))))
                      (if options (format "[%s]" (mapconcat #'identity options ",")) ""))
                    poster-path movie-path)))
  (message "Poster created; movie inserted. Preamble needs \\usepackage{multimedia} and \\usepackage{graphicx}."))

(provide 'slidepilot-movie)
;;; slidepilot-movie.el ends here
