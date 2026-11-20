;;; -*- lexical-binding: nil; -*-
;; 1. Configure nov.el for EPUBs
(use-package nov
  :ensure t
  ;; Automatically use nov-mode for .epub files
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (setq nov-text-width 80)) ; Optional: constrain text width for better readability

;; 2. Configure calibredb
(defcustom my/calibre-library-directory (expand-file-name "~/Calibre Library")
  "Local Calibre library, when present on this machine."
  :type 'directory
  :group 'files)

(defun my/calibre-program (name)
  "Find Calibre program NAME on PATH or in an installed macOS application."
  (or (executable-find name)
      (and (eq system-type 'darwin)
           (cl-find-if
            #'file-executable-p
            (mapcar (lambda (directory)
                      (expand-file-name (concat "calibre.app/Contents/MacOS/" name)
                                        directory))
                    (list "/Applications" (expand-file-name "~/Applications")))))))

(use-package calibredb
  :ensure t
  :if (and (my/calibre-program "calibredb")
           (file-readable-p
            (expand-file-name "metadata.db" my/calibre-library-directory)))
  :defer t
  :config
  (setq calibredb-program (my/calibre-program "calibredb"))
  (when-let* ((program (my/calibre-program "calibre-debug")))
    (setq calibredb-debug-program program))
  (when-let* ((program (my/calibre-program "ebook-convert")))
    (setq calibredb-convert-program program))
  (setq calibredb-root-dir my/calibre-library-directory)
  (setq calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
  (setq calibredb-library-alist
        (list (list my/calibre-library-directory '(name . "Calibre"))))

  (defun my/calibredb-open-file-with-emacs (&optional candidate)
    "Open file with Emacs natively.
Optional argument CANDIDATE is the selected item."
    (interactive "P")
    (unless candidate
      (setq candidate (car (calibredb-find-candidate-at-point))))

    ;; The 't' argument ensures calibredb prompts you to choose a format
    ;; if the book exists as both PDF and EPUB in your library.
    (let ((filepath (calibredb-get-file-path candidate t)))
      (if filepath
          (find-file filepath)
        (message "No file found for this candidate."))))

  ;; Bind the custom function to 'V' in the search mode map
  :bind (:map calibredb-search-mode-map
              ("V" . my/calibredb-open-file-with-emacs)))
