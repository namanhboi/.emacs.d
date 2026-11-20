;;; git.el --- Git tools -*- lexical-binding: t; -*-

;; Refresh archive metadata before installing a missing MELPA package.
(prelude-require-package 'remoto)

(use-package remoto
  :ensure nil
  :config
  ;; These integrations require a real process environment on the remote host.
  (customize-set-variable
   'remoto-inhibited-functions
   (append '(envrc-global-mode-enable-in-buffer prelude-lsp-enable)
           (remove 'envrc-global-mode-enable-in-buffer
                   (remove 'prelude-lsp-enable remoto-inhibited-functions))))
  (global-remoto-mode 1))
