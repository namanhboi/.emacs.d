;;; Envrc - Direnv integration for Emacs

(use-package envrc
  :ensure t
  :config
  ;; Enable envrc globally so it automatically looks for .envrc files
  (envrc-global-mode 1)

  ;; Optional: If you use the modeline indicator, you can customize the string
  ;; (setq envrc-debug nil)
  )

;; Ensure Eglot (LSP) waits for envrc to set the environment
;; before it tries to find a language server.
(with-eval-after-load 'eglot
  (add-hook 'eglot-managed-mode-hook #'envrc-mode))
