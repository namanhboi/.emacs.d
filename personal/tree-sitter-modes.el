;;; tree-sitter-modes.el --- Prefer available Tree-sitter modes -*- lexical-binding: t; -*-

(use-package treesit-auto
  :ensure t
  :demand t
  ;; Grammar installation is handled separately, rather than blocking file opens.
  :custom
  (treesit-auto-install nil)
  :config
  ;; Keep the traditional Verilog mode for macro-heavy course code.
  (setq treesit-auto-langs
        (remq 'systemverilog (remq 'verilog treesit-auto-langs)))
  ;; Only register modes whose implementation and grammar are both available.
  (treesit-auto-add-to-auto-mode-alist)
  (global-treesit-auto-mode 1))
