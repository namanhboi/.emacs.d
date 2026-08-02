;;; Envrc - Direnv integration for Emacs

(use-package envrc
  :ensure t
  :custom
  (envrc-remote t)
  :config
  ;; Enable envrc globally so it automatically looks for .envrc files
  (envrc-global-mode 1)

  ;; Optional: If you use the modeline indicator, you can customize the string
  ;; (setq envrc-debug nil)
  )

;; Prelude starts Eglot from major-mode hooks, before globalized minor modes
;; normally activate.  Apply direnv first so the initial language-server
;; process inherits the remote environment and PATH.
(defun my/envrc-before-prelude-lsp (original-function &rest arguments)
  "Apply envrc before ORIGINAL-FUNCTION starts an LSP client."
  (when (and envrc-global-mode
             (not envrc-mode))
    (envrc-mode 1))
  (apply original-function arguments))

(advice-add 'prelude-lsp-enable :around #'my/envrc-before-prelude-lsp)
