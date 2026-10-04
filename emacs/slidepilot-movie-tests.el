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
            (should (file-exists-p (expand-file-name "a movie-poster.png" directory)))))
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
