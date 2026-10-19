;;; slidepilot-movie-tests.el --- Movie insertion checks -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'slidepilot-movie)

(ert-deftest slidepilot-movie-inserts-relative-paths-and-preserves-sizing ()
  (let* ((directory (make-temp-file "slidepilot-test-" t))
         (movie (expand-file-name "a movie.mp4" directory)))
    (unwind-protect
        (progn
          (write-region "movie" nil movie nil 'silent)
          (with-temp-buffer
            (setq buffer-file-name (expand-file-name "slides.tex" directory))
            (cl-letf (((symbol-function 'executable-find) (lambda (_) t))
                      ((symbol-function 'call-process)
                       (lambda (&rest args)
                         (should (member movie args))
                         (write-region "poster" nil (car (last args)) nil 'silent)
                         0)))
              (slidepilot-insert-movie movie))
            (should (string-match-p (regexp-quote "\\detokenize{a movie.mp4}") (buffer-string)))
            (should (string-match-p "keepaspectratio" (buffer-string)))
            (should-not (string-match-p "autostart" (buffer-string)))
            (should (file-exists-p (expand-file-name "a movie-poster.png" directory)))))
      (delete-directory directory t))))

(ert-deftest slidepilot-movie-autostart-and-loop-add-options ()
  (let* ((directory (make-temp-file "slidepilot-test-" t))
         (movie (expand-file-name "movie.mp4" directory)))
    (unwind-protect
        (progn
          (write-region "movie" nil movie nil 'silent)
          (with-temp-buffer
            (setq buffer-file-name (expand-file-name "slides.tex" directory))
            (cl-letf (((symbol-function 'executable-find) (lambda (_) t))
                      ((symbol-function 'y-or-n-p) (lambda (_) t))
                      ((symbol-function 'call-process)
                       (lambda (&rest args)
                         (write-region "poster" nil (car (last args)) nil 'silent)
                         0)))
              (slidepilot-insert-movie movie t)
              (slidepilot-insert-movie movie nil t)
              (slidepilot-insert-movie movie t t))
            (should (string-match-p (regexp-quote "\\movie[autostart]\n") (buffer-string)))
            (should (string-match-p (regexp-quote "\\movie[loop]\n") (buffer-string)))
            (should (string-match-p (regexp-quote "\\movie[autostart,loop]\n") (buffer-string)))))
      (delete-directory directory t))))

(ert-deftest slidepilot-movie-failure-leaves-buffer-unchanged ()
  (let* ((directory (make-temp-file "slidepilot-test-" t))
         (movie (expand-file-name "movie.mp4" directory)))
    (unwind-protect
        (progn
          (write-region "movie" nil movie nil 'silent)
          (with-temp-buffer
            (setq buffer-file-name (expand-file-name "slides.tex" directory))
            (insert "original")
            (cl-letf (((symbol-function 'executable-find) (lambda (_) t))
                      ((symbol-function 'call-process) (lambda (&rest _) 1)))
              (should-error (slidepilot-insert-movie movie) :type 'user-error))
            (should (equal (buffer-string) "original"))
            (should-not (file-exists-p (expand-file-name "movie-poster.png" directory)))))
      (delete-directory directory t))))

(ert-deftest slidepilot-movie-url-youtube-uses-thumbnail-poster ()
  (let ((directory (make-temp-file "slidepilot-test-" t)))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name "slides.tex" directory))
          (cl-letf (((symbol-function 'call-process) (lambda (&rest _) (error "FFmpeg not needed")))
                    ((symbol-function 'url-copy-file)
                     (lambda (url file &rest _)
                       (should (equal url "https://img.youtube.com/vi/P25BwtepmUk/hqdefault.jpg"))
                       (write-region "poster" nil file nil 'silent))))
            (slidepilot-insert-movie-url "https://www.youtube.com/watch?v=P25BwtepmUk" t t))
          (should (string-match-p (regexp-quote "\\movie[autostart,loop]\n") (buffer-string)))
          (should (string-match-p (regexp-quote "{\\detokenize{P25BwtepmUk-poster.jpg}}") (buffer-string)))
          (should (string-match-p (regexp-quote "{\\detokenize{https://www.youtube.com/watch?v=P25BwtepmUk}}")
                                  (buffer-string)))
          (should (file-exists-p (expand-file-name "P25BwtepmUk-poster.jpg" directory))))
      (delete-directory directory t))))

(ert-deftest slidepilot-movie-url-file-escapes-and-uses-ffmpeg ()
  (let ((directory (make-temp-file "slidepilot-test-" t))
        (url "https://example.com/clips/a%20b.mp4#t=1"))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name "slides.tex" directory))
          (cl-letf (((symbol-function 'executable-find) (lambda (_) t))
                    ((symbol-function 'call-process)
                     (lambda (&rest args)
                       (should (member url args))
                       (write-region "poster" nil (car (last args)) nil 'silent)
                       0)))
            (slidepilot-insert-movie-url url))
          (should (string-match-p (regexp-quote "{\\detokenize{https://example.com/clips/a\\04520b.mp4\\043t=1}}")
                                  (buffer-string)))
          (should (file-exists-p (expand-file-name "a-b-poster.png" directory))))
      (delete-directory directory t))))

(ert-deftest slidepilot-movie-url-rejects-non-web-addresses ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/slides.tex")
    (insert "original")
    (should-error (slidepilot-insert-movie-url "ftp://example.com/movie.mp4") :type 'user-error)
    (should-error (slidepilot-insert-movie-url "https://example.com/a movie.mp4") :type 'user-error)
    (should (equal (buffer-string) "original"))))

(ert-deftest slidepilot-movie-youtube-ids ()
  (dolist (url '("https://youtu.be/P25BwtepmUk" "https://m.youtube.com/watch?feature=share&v=P25BwtepmUk"
                 "https://www.youtube.com/embed/P25BwtepmUk?start=3" "https://youtube.com/shorts/P25BwtepmUk"))
    (should (equal (slidepilot-movie--youtube-id url) "P25BwtepmUk")))
  (should-not (slidepilot-movie--youtube-id "https://example.com/watch?v=P25BwtepmUk")))
