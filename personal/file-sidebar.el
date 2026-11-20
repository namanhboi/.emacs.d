;;; file-sidebar.el --- Speedbar sidebar following Prot's setup -*- lexical-binding: t; -*-

;; Adapted from Protesilaos Stavrou's Speedbar configuration:
;; https://protesilaos.com/emacs/dotemacs

(require 'imenu)
(require 'subr-x)

(defun nam/speedbar-buffer-setup ()
  "Keep the tree free of Prelude's global line-number gutter."
  (display-line-numbers-mode -1))

(defun nam/speedbar-initialize-window (&optional arg)
  "Initialize the Speedbar buffer before opening its side window.
Emacs 31.1's window path omits `speedbar-mode', unlike its frame path."
  (unless (or (and (numberp arg) (< arg 0))
              (and (null arg) (speedbar-window--live-p)))
    (unless (buffer-live-p speedbar-buffer)
      (setq speedbar-buffer (get-buffer-create speedbar--buffer-name)))
    (with-current-buffer speedbar-buffer
      (unless (derived-mode-p 'speedbar-mode)
        (speedbar-mode)))))

(defun nam/speedbar-close-window ()
  "Close the Speedbar sidebar, leaving its parent frame intact."
  (interactive)
  (speedbar-window-mode -1))

(defun nam/speedbar-window-keys ()
  "Use sidebar close commands instead of dedicated-frame commands."
  (when (speedbar-window--live-p)
    (with-current-buffer speedbar-buffer
      (setq-local dframe-controlled nil)
      (local-set-key (kbd "q") #'nam/speedbar-close-window)
      (local-set-key (kbd "Q") #'nam/speedbar-close-window))))

(defun nam/speedbar-imenu-flatten (elements)
  "Flatten Imenu ELEMENTS and remove the outer grouping prefix."
  (delq nil
        (mapcar
         (lambda (entry)
           (let ((name (car entry)) (position (cdr entry)))
             (when (and (stringp name)
                        (or (natnump position) (markerp position)))
               (cons (if (string-match ":" name)
                         (string-join (split-string (substring name (match-end 0)) ":") " ")
                       name)
                     position))))
         (imenu--flatten-index-alist elements t))))

(use-package speedbar
  :ensure nil
  :bind (("<f8>" . speedbar-get-focus)
         ("<S-f8>" . speedbar))
  :hook (speedbar-mode . nam/speedbar-buffer-setup)
  :custom
  (speedbar-use-images nil)
  (speedbar-smart-directory-expand-flag nil)
  (speedbar-prefer-window t)
  (speedbar-window-default-width 60)
  (speedbar-window-max-width 60)
  (speedbar-indentation-width 4)
  (speedbar-show-unknown-files t)
  ;; Released Emacs 31.1 still passes these directly to string-match-p.
  ;; Match only the empty string to hide no filenames (Prot uses nil).
  (speedbar-directory-unshown-regexp "\\`\\'")
  (speedbar-file-unshown-regexp "\\`\\'")
  :config
  (advice-add 'speedbar-window-mode :before #'nam/speedbar-initialize-window)
  (add-hook 'speedbar-reconfigure-keymaps-hook #'nam/speedbar-window-keys)
  (setq speedbar--window-width speedbar-window-default-width)
  (add-hook 'speedbar-visiting-tag-hook #'speedbar-recenter)
  (add-hook 'speedbar-visiting-tag-hook #'speedbar-highlight-one-tag-line t)
  (setq speedbar-tag-hierarchy-method '(nam/speedbar-imenu-flatten))
  (when (buffer-live-p speedbar-buffer)
    (nam/speedbar-initialize-window 1)
    (with-current-buffer speedbar-buffer (nam/speedbar-buffer-setup))
    (when (speedbar-window--live-p) (speedbar-reconfigure-keymaps))))
