;;; slidepilot-movie.el --- Insert PDF movies with generated posters -*- lexical-binding: t; -*-

;;; Commentary:
;; Load this file and run M-x slidepilot-insert-movie in a saved LaTeX buffer.
;; Requires ffmpeg on `exec-path' and \\usepackage{multimedia} in the preamble.

;;; Code:

(defgroup slidepilot-movie nil
  "Insert movies for PDF presentations."
  :group 'tex)

(defcustom slidepilot-movie-ffmpeg-program "ffmpeg"
  "FFmpeg executable used to extract the first video frame."
  :type 'string)

(defun slidepilot-insert-movie (movie)
  "Generate a poster for MOVIE and insert a centered LaTeX movie at point.
The poster is named MOVIE's base name followed by -poster.png, beside
MOVIE.  Ask before replacing an existing poster.  Paths are relative
to the current LaTeX file.  Limit the movie to text width and 72 percent
of text height, retaining its aspect ratio so it fits below a slide title.
The buffer must visit a file, but this command does not save the buffer."
  (interactive (list (read-file-name "Movie file: " nil nil t)))
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
    (when (and (file-exists-p poster)
               (not (y-or-n-p (format "Replace poster %s? " poster))))
      (user-error "Cancelled; poster and buffer unchanged"))
    (let ((temporary (make-temp-file (expand-file-name ".slidepilot-poster-" (file-name-directory movie)) nil ".png")))
      (unwind-protect
          (with-temp-buffer
            (let ((status (call-process slidepilot-movie-ffmpeg-program nil t nil
                                        "-nostdin" "-hide_banner" "-loglevel" "error" "-y"
                                        "-i" movie "-map" "0:v:0" "-frames:v" "1" temporary)))
              (unless (and (integerp status) (zerop status)
                           (> (file-attribute-size (file-attributes temporary)) 0))
                (user-error "FFmpeg could not generate a poster: %s" (buffer-string)))
              (rename-file temporary poster t)))
        (when (file-exists-p temporary) (delete-file temporary))))
    (atomic-change-group
      (insert (format "\n\\par\n\\begin{center}\n  \\movie\n    {\\includegraphics[width=\\textwidth,height=0.72\\textheight,keepaspectratio]{\\detokenize{%s}}}\n    {\\detokenize{%s}}\n\\end{center}\n"
                      poster-path movie-path)))
    (message "Poster created; movie inserted. Preamble needs \\usepackage{multimedia} and \\usepackage{graphicx}.")))

(provide 'slidepilot-movie)
;;; slidepilot-movie.el ends here
