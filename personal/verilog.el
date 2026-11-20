;;; verilog.el --- Verilog editing with starter-code indentation -*- lexical-binding: t; -*-

(use-package verilog-mode
  :ensure nil
  :demand t
  :mode "\\.s?vh?\\'"
  :bind (:map verilog-mode-map
              ("TAB" . nam/verilog-tab)
              ("<tab>" . nam/verilog-tab)))

(defun nam/verilog-tab (arg)
  "Indent with the Verilog engine, then complete if indentation is unchanged.
With prefix ARG or an active region, only indent."
  (interactive "P")
  (let ((tick (buffer-chars-modified-tick))
        (region (use-region-p)))
    (electric-verilog-tab)
    (when (and (not arg) (not region)
               (eq tab-always-indent 'complete)
               (= tick (buffer-chars-modified-tick))
               (not (save-excursion (skip-chars-backward " \t") (bolp))))
      (completion-at-point))))

(defun nam/verilog-starter-style ()
  "Use two-space starter-code indentation, including macro-based blocks."
  (setq-local indent-tabs-mode nil
              verilog-indent-level 2
              verilog-indent-level-module 2
              verilog-indent-level-declaration 2
              verilog-indent-level-behavioral 2
              verilog-indent-level-directive 0
              verilog-case-indent 2
              verilog-indent-lists nil
              indent-line-function #'verilog-indent-line-relative
              indent-region-function nil
              comment-indent-function #'verilog-comment-indent))

(add-hook 'verilog-mode-hook #'nam/verilog-starter-style)

(defvar flycheck-verilator-include-path nil)

(defun nam/verilog-flycheck-includes ()
  "Add the ancestor containing a relative Verilog include to Flycheck.
Keep explicitly configured directories first.  Relative paths also work
when the checker runs on a TRAMP host."
  (when (and buffer-file-name (derived-mode-p 'verilog-mode)
             (bound-and-true-p flycheck-mode))
    (save-excursion
      (goto-char (point-min))
      (let (root)
        (while (and (not root)
                    (re-search-forward
                     "^[ \t]*`include[ \t]+\"\\([^\"\n]+/[^\"\n]+\\)\"" nil t))
          (let ((include (match-string-no-properties 1)))
            (unless (file-name-absolute-p include)
              (setq root
                    (locate-dominating-file
                     buffer-file-name
                     (lambda (directory)
                       (file-exists-p (expand-file-name include directory))))))))
        (when root
          (let ((directory (file-relative-name
                            root (file-name-directory buffer-file-name))))
            (unless (member directory flycheck-verilator-include-path)
              (setq-local flycheck-verilator-include-path
                          (append flycheck-verilator-include-path
                                  (list directory))))))))))

(add-hook 'hack-local-variables-hook #'nam/verilog-flycheck-includes)

;;; verilog.el ends here
