;;; personal-portability-test.el --- Optional dependency checks -*- lexical-binding: t; -*-

;; Load init.el before this file, then run ert-run-tests-batch-and-exit.
(require 'ert)
(require 'cl-lib)

(ert-deftest nam/pdf-viewer-platform-fallbacks ()
  (let ((my/pdf-viewer-program nil))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program &optional _remote)
                 (pcase program
                   ("open" "/usr/bin/open")
                   ("xdg-open" "/usr/bin/xdg-open")))))
      (let ((system-type 'darwin))
        (should (equal (my/pdf-viewer-executable) "/usr/bin/open")))
      (let ((system-type 'gnu/linux))
        (should (equal (my/pdf-viewer-executable) "/usr/bin/xdg-open"))))
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil)))
      (should-not (my/pdf-viewer-executable)))))

(ert-deftest nam/calibre-import-skips-unavailable-sqlite ()
  (cl-letf (((symbol-function 'sqlite-available-p) (lambda () nil))
            ((symbol-function 'file-readable-p) (lambda (_) t))
            ((symbol-function 'sqlite-open)
             (lambda (&rest _) (ert-fail "SQLite was used when unavailable"))))
    (should-not (nam/elfeed-calibre-available-p))
    (should-not (nam/elfeed-calibre-import-issues))))

(ert-deftest nam/calibre-finds-macos-application-tools ()
  (let ((system-type 'darwin))
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
              ((symbol-function 'file-executable-p)
               (lambda (file)
                 (equal file "/Applications/calibre.app/Contents/MacOS/calibredb"))))
      (should (equal (my/calibre-program "calibredb")
                     "/Applications/calibre.app/Contents/MacOS/calibredb")))))

(ert-deftest nam/org-roam-skips-missing-notes ()
  (let ((my/org-roam-directory "/nonexistent-emacs-portability-test/notes"))
    (cl-letf (((symbol-function 'sqlite-available-p) (lambda () t)))
      (should-not (my/org-roam-available-p)))))

(ert-deftest nam/direnv-advice-preserves-lsp-without-direnv ()
  (let ((envrc-global-mode nil))
    (with-temp-buffer
      (cl-letf (((symbol-function 'envrc-mode)
                 (lambda (&rest _) (ert-fail "envrc was enabled unexpectedly"))))
        (should (eq (my/envrc-before-prelude-lsp (lambda () 'started))
                    'started))))))

(ert-deftest nam/latex-mode-skips-missing-spell-checker ()
  (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
            ((symbol-function 'flyspell-mode)
             (lambda (&rest _) (ert-fail "Missing spell checker was started"))))
    (with-temp-buffer
      (LaTeX-mode)
      (should-not (bound-and-true-p flyspell-mode)))))

(ert-deftest nam/rust-mode-skips-missing-tools ()
  (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
            ((symbol-function 'prelude-lsp-enable)
             (lambda (&rest _) (ert-fail "Missing language server was started"))))
    (with-temp-buffer
      (rust-mode)
      (should-not (bound-and-true-p eglot--managed-mode)))))

;;; personal-portability-test.el ends here
