;; Disable Prelude's undo-tree before it even loads
(setq prelude-undo-tree nil)
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)
(setq redisplay-skip-fontification-on-input t)
(setq read-process-output-max (* 4 1024 1024)) ; 4MB
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)
(setq save-interprogram-paste-before-kill t)
(setq kill-do-not-save-duplicates t)
(setq savehist-additional-variables
      '(search-ring regexp-search-ring kill-ring))
(add-hook 'savehist-save-hook
          (lambda ()
            (setq kill-ring
                  (mapcar #'substring-no-properties
                          (cl-remove-if-not #'stringp kill-ring)))))
(add-hook 'after-save-hook
          #'executable-make-buffer-file-executable-if-script-p)
(setq reb-re-syntax 'string)
(setq ffap-machine-p-known 'reject)
(setq window-combination-resize t)

;; Copy Emacs kill-ring to the remote machine's X clipboard, if available.
(use-package xclip
  :ensure t
  :if (and (executable-find "xclip")
           (getenv "DISPLAY"))
  :config
  (xclip-mode +1))

;; Copy Emacs kill-ring to your local/laptop clipboard through OSC52.
(use-package clipetty
  :ensure t
  :config
  (global-clipetty-mode +1))
(winner-mode +1)

(defun toggle-delete-other-windows ()
  "Delete other windows in frame if any, or restore previous window config."
  (interactive)
  (if (and winner-mode
           (equal (selected-window) (next-window)))
      (winner-undo)
    (delete-other-windows)))

(global-set-key (kbd "C-x 1") #'toggle-delete-other-windows)
(setq set-mark-command-repeat-pop t)
(advice-add 'save-place-find-file-hook :after
            (lambda (&rest _)
              (when buffer-file-name (ignore-errors (recenter)))))
(setq help-window-select t)
;; disable smartparens
(with-eval-after-load 'smartparens
  ;; Make the toggle functions do absolutely nothing
  (advice-add 'smartparens-mode :around #'ignore)
  (advice-add 'smartparens-global-mode :around #'ignore)
  (smartparens-global-mode -1))

;; fix copying and pasting from terminal emacs
;; (setq x-select-enable-clipboard t
      ;; x-select-enable-primary t)
;; (unless (display-graphic-p)
;;   (setq interprogram-paste-function
;;         (lambda ()
;;           (shell-command-to-string "wl-paste"))))

(global-set-key (kbd "C-x c") #'compile)
