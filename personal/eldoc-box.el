;;; my-eldoc-box.el --- eldoc/eldoc-box configuration -*- lexical-binding: t -*-

(if (display-graphic-p)
    ;; GUI Emacs: use eldoc-box popup.
    (progn
      (prelude-require-packages '(eldoc-box))
      (require 'eldoc-box)

      (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-at-point-mode)

      (with-eval-after-load 'eldoc-box
        (setq eldoc-box-clear-echo-area t)
        (setq eldoc-box-max-pixel-width 800)
        (setq eldoc-box-max-pixel-height 600)
        (add-hook 'eldoc-box-buffer-hook #'visual-line-mode))

      (with-eval-after-load 'eglot
        (define-key eglot-mode-map
                    (kbd "C-c C-l d")
                    #'eldoc-box-help-at-point)))

  ;; Terminal Emacs: use normal Eldoc in the echo area.
  (setq eldoc-echo-area-use-multiline-p 3)
  (setq eldoc-idle-delay 0.3)

  (with-eval-after-load 'eglot
    (define-key eglot-mode-map
                (kbd "C-c C-l d")
                #'eldoc-doc-buffer)))

(provide 'my-eldoc-box)
