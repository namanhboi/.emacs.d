;;; navigation.el --- Center and highlight navigation targets -*- lexical-binding: t; -*-

;;; Commentary:

;; Keep source locations centered while browsing definitions and search results.

;;; Code:

(require 'pulse)
(declare-function xref-pulse-momentarily "xref")
(declare-function consult-imenu "consult-imenu" (&optional selected))
(declare-function consult-imenu-multi "consult-imenu" (&optional query))

;; Prelude already enables Isearch's match counter before the prompt.
(setq lazy-count-suffix-format nil
      search-whitespace-regexp ".*?")

;; Keep two lines of context when ordinary cursor movement scrolls the window.
(setq scroll-margin 2)

(defun nam/show-current-buffer-other-window ()
  "Select another window showing this buffer at point, splitting if needed."
  (interactive)
  (let ((buffer (current-buffer))
        (position (point)))
    (switch-to-buffer-other-window buffer)
    (goto-char position)))

(global-set-key (kbd "C-x 4 o") #'nam/show-current-buffer-other-window)

(defun nam/imenu-current-buffer-other-window ()
  "Show this buffer in another window, then search its definitions there."
  (interactive)
  (nam/show-current-buffer-other-window)
  (call-interactively #'consult-imenu))

(global-set-key (kbd "C-x 4 i") #'nam/imenu-current-buffer-other-window)

(defun nam/imenu-project-buffers-other-window ()
  "Show this buffer in another window, then search project buffer definitions."
  (interactive)
  (nam/show-current-buffer-other-window)
  (call-interactively #'consult-imenu-multi))

(global-set-key (kbd "C-x 4 I") #'nam/imenu-project-buffers-other-window)

(defun nam/recenter-after-mark-jump (&rest _ignored)
  "Center the destination of a user mark-jump command."
  (when (and (memq this-command '(set-mark-command pop-to-mark-command
                                  pop-global-mark exchange-point-and-mark))
             (eq (current-buffer) (window-buffer (selected-window))))
    (recenter '(4))))

(dolist (command '(pop-to-mark-command pop-global-mark exchange-point-and-mark))
  (advice-add command :after #'nam/recenter-after-mark-jump))

(defface nam/navigation-target
  '((t (:inherit region :extend t)))
  "Full-width highlight for definition jumps and search result previews."
  :group 'convenience)

(defun nam/recenter-after-definition (&rest _ignored)
  "Center and highlight a jump or preview destination in its window."
  (when (eq (current-buffer) (window-buffer (selected-window)))
    (recenter '(4))
    (let ((pulse-delay 0.05)
          (pulse-iterations 16))
      (pulse-momentary-highlight-region
       (line-beginning-position)
       (min (point-max) (1+ (line-end-position)))
       'nam/navigation-target)
      ;; Keep the full-line background above match-only preview overlays.
      (when (overlayp pulse-momentary-overlay)
        (overlay-put pulse-momentary-overlay 'priority 100)
        (overlay-put pulse-momentary-overlay 'window (selected-window))))))

;; Both ordinary grep/compilation results and Embark's Occur/grep exports use
;; next-error-no-select for n/p.  The hook runs in the source window, preserving
;; keyboard focus in the result list.
(add-hook 'next-error-hook #'nam/recenter-after-definition 90)

(with-eval-after-load 'replace
  (add-hook 'occur-mode-find-occurrence-hook #'nam/recenter-after-definition 90))

(with-eval-after-load 'xref
  ;; Run last so other jump hooks cannot leave the destination off-center.
  (remove-hook 'xref-after-jump-hook #'recenter)
  (remove-hook 'xref-after-jump-hook #'xref-pulse-momentarily)
  (remove-hook 'xref-after-return-hook #'xref-pulse-momentarily)
  (add-hook 'xref-after-jump-hook #'nam/recenter-after-definition 90)
  (add-hook 'xref-after-return-hook #'nam/recenter-after-definition 90))

(with-eval-after-load 'find-func
  (add-hook 'find-function-after-hook #'nam/recenter-after-definition 90))

(with-eval-after-load 'consult
  ;; This hook also runs for Consult/Embark Collect live previews.
  (remove-hook 'consult-after-jump-hook #'recenter)
  (add-hook 'consult-after-jump-hook #'nam/recenter-after-definition 90))

(with-eval-after-load 'embark-consult
  ;; These actions pulse again after Consult's hook; keep our full-line pulse.
  (dolist (command '(embark-consult-goto-location embark-consult-goto-grep))
    (advice-add command :after #'nam/recenter-after-definition)))

(use-package dumb-jump
  :ensure t
  :demand t
  :custom
  (dumb-jump-prefer-searcher 'rg)
  :config
  (add-to-list 'dumb-jump-language-aliases-alist '("verilog" . "systemverilog"))
  (dolist (extension '("v" "vh"))
    (add-to-list 'dumb-jump-language-file-exts
                 `(:language "systemverilog" :ext ,extension
                   :agtype "verilog" :rgtype "verilog")))
  ;; Let language servers and mode-specific backends take precedence.
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate 90))

(provide 'nam-navigation)
;;; navigation.el ends here
