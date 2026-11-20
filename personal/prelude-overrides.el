;;; prelude-overrides.el --- Personal Prelude preferences -*- lexical-binding: t; -*-

;; Keep navigation and editing preferences out of Prelude's core.
(dolist (key '("C-c n" "C-c f" "C-c i"))
  (define-key prelude-mode-map (kbd key) nil))
(dolist (key '("C-:" "C-'" "M-g w" "s-," "s-." "C-c v"
               "S-<up>" "S-<down>" "S-<left>" "S-<right>"))
  (global-unset-key (kbd key)))
(global-set-key (kbd "M-z") #'zap-to-char)
(global-unset-key (kbd "M-Z"))
(global-set-key (kbd "M-g f") #'consult-flymake)
(global-set-key (kbd "M-g e") #'consult-compile-error)
(global-set-key (kbd "M-j") #'avy-goto-char-timer)
(define-key isearch-mode-map (kbd "M-j") #'avy-isearch)
(global-set-key (kbd "C-x o") #'ace-window)
(global-set-key [remap other-window] #'ace-window)
(setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
(global-set-key (kbd "M-<backspace>") #'backward-kill-word)
(global-set-key (kbd "M-DEL") #'backward-kill-word)
(with-eval-after-load 'smartparens
  (define-key smartparens-mode-map (kbd "M-<backspace>") nil)
  (define-key smartparens-mode-map (kbd "M-DEL") nil))
(remove-hook 'text-mode-hook #'prelude-enable-flyspell)
(setq whitespace-style '(face tabs empty trailing))
;; Restore Prelude's whitespace cleanup when saving.
(setq prelude-clean-whitespace-on-save t)
