;;; kkp.el --- Kitty Keyboard Protocol support in terminal Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Preserve otherwise ambiguous modified key combinations when Emacs runs in a
;; compatible terminal, including through recent versions of tmux.

;;; Code:

(use-package kkp
  :ensure t
  :hook (tty-setup . global-kkp-mode)
  :config
  ;; KKP encodes C-g as an escape sequence.  Temporarily restore legacy key
  ;; encoding while envrc runs a blocking direnv subprocess so C-g can still
  ;; interrupt it.
  (with-eval-after-load 'envrc
    (unless (advice-member-p #'kkp-restore-legacy-keys 'envrc--export)
      (advice-add 'envrc--export :around #'kkp-restore-legacy-keys))))

(provide 'personal-kkp)
;;; kkp.el ends here
