;;; -*- lexical-binding: t; -*-
;;; Envrc - Direnv integration for Emacs

(use-package envrc
  :ensure t
  :custom
  (envrc-remote t)
  (envrc-async t)
  :config
  ;; Enable envrc globally so it automatically looks for .envrc files
  (envrc-global-mode 1)

  ;; Optional: If you use the modeline indicator, you can customize the string
  ;; (setq envrc-debug nil)
  )

;; Prelude starts Eglot from major-mode hooks, before globalized minor modes
;; normally activate.  Wait for the environment without blocking Emacs.
(defvar-local nam/envrc-lsp-pending nil
  "Non-nil when Prelude's LSP startup is waiting for this buffer's environment.")

(defun my/envrc-before-prelude-lsp (original-function &rest arguments)
  "Run ORIGINAL-FUNCTION with ARGUMENTS once direnv has supplied its environment."
  (when (and envrc-global-mode
             (not envrc-mode))
    (envrc-mode 1))
  (if (bound-and-true-p envrc--running)
      (setq nam/envrc-lsp-pending t)
    (setq nam/envrc-lsp-pending nil)
    (apply original-function arguments)))

(defun nam/envrc-resume-lsp (buffer _result)
  "Resume pending LSP startup in BUFFER after envrc applies its RESULT."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and nam/envrc-lsp-pending
                 envrc-mode
                 (not envrc--running))
        (setq nam/envrc-lsp-pending nil)
        (prelude-lsp-enable)))))

(advice-add 'prelude-lsp-enable :around #'my/envrc-before-prelude-lsp)
(with-eval-after-load 'envrc
  (advice-add 'envrc--apply :after #'nam/envrc-resume-lsp))
