;;; diagnostics.el --- Diagnostics only in language-server buffers -*- lexical-binding: t; -*-

(defun nam/diagnostics-require-language-server ()
  "Disable standalone Flycheck and Flymake outside Eglot/LSP buffers.
Language-server clients remain responsible for enabling their diagnostics."
  (unless (or (bound-and-true-p eglot--managed-mode)
              (bound-and-true-p lsp-managed-mode))
    (when (bound-and-true-p flycheck-mode)
      (flycheck-mode -1))
    (when (bound-and-true-p flymake-mode)
      (flymake-mode -1))))

(dolist (hook '(flycheck-mode-hook flymake-mode-hook
               eglot-managed-mode-hook lsp-managed-mode-hook lsp-mode-hook))
  (add-hook hook #'nam/diagnostics-require-language-server))

(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (nam/diagnostics-require-language-server)))

;;; diagnostics.el ends here
