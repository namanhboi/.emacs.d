;;; -*- lexical-binding: nil; -*-
;; 1. Configure nov.el for EPUBs
(use-package nov
  :ensure t
  ;; Automatically use nov-mode for .epub files
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (setq nov-text-width 80)) ; Optional: constrain text width for better readability

;; 2. Configure calibredb
(use-package calibredb
  :defer t
  :config
  (setq calibredb-root-dir "/home/nam/Calibre Library")
  (setq calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
  (setq calibredb-library-alist '(("/home/nam/Calibre Library" (name . "Calibre"))))

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
