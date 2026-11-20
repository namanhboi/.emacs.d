;;; completion.el --- Personal completion preferences -*- lexical-binding: t; -*-
(with-eval-after-load 'company
  (global-company-mode -1)
  (define-key company-mode-map [remap indent-for-tab-command]
              #'company-indent-or-complete-common))

(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)
   ("C-h B" . embark-bindings))
  :init
  ;; Replace the regular prefix help command with Embark's contextual bindings.
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  ;; Keep the Embark live/completions buffers out of the way.
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package embark-consult
  :ensure t
  :after (embark consult))


;; TAB indents first, then requests Corfu; Company remains the LaTeX frontend.
(setq tab-always-indent 'complete)
(use-package corfu
  :ensure t
  :custom
  (corfu-auto nil)
  :config
  (setq global-corfu-modes '((not LaTeX-mode latex-mode) t))
  (global-corfu-mode 1)
  (require 'corfu-popupinfo)
  (setq corfu-popupinfo-delay '(0.5 . 0.2))
  (corfu-popupinfo-mode 1)
  (require 'corfu-history)
  (corfu-history-mode 1)
  (with-eval-after-load 'savehist
    (add-to-list 'savehist-additional-variables 'corfu-history)))

(defun nam/completion-preview-setup ()
  "Enable inline hints in Corfu programming, text, and agent shell buffers."
  (completion-preview-mode
   (if (and (bound-and-true-p corfu-mode)
            (derived-mode-p 'prog-mode 'text-mode 'agent-shell-mode)
            (not (derived-mode-p 'LaTeX-mode 'latex-mode)))
       1 -1)))

(defun nam/completion-preview-inhibit-for-popup ()
  "Hide inline hints while the completion menu handles input."
  (bound-and-true-p completion-in-region-mode))

(declare-function agent-shell--prompt-input-start "agent-shell-prompt")
(declare-function agent-shell-next-item "agent-shell" (&optional leave-table))

(defun nam/agent-shell-editable-input-p ()
  "Return non-nil when point is in Agent Shell's live, editable input."
  (and (derived-mode-p 'agent-shell-mode)
       (not buffer-read-only)
       (when-let* ((start (agent-shell--prompt-input-start)))
         (>= (point) start))
       (not (get-char-property (point) 'read-only))))

(defun nam/completion-preview-inhibit-for-agent-output ()
  "Keep inline hints out of Agent Shell's conversation history and output."
  (and (derived-mode-p 'agent-shell-mode)
       (not (nam/agent-shell-editable-input-p))))

(defun nam/agent-shell-tab (arg)
  "Complete live prompt input, or navigate conversation items with ARG."
  (interactive "P")
  (if (and (not arg) (nam/agent-shell-editable-input-p))
      (completion-at-point)
    (agent-shell-next-item arg)))

(defun nam/agent-shell-comint-capf ()
  "Allow word completion when Comint has no matching filename."
  (cape-wrap-nonexclusive #'comint-completion-at-point))

(defun nam/agent-shell-completion-setup ()
  "Keep Agent Shell's native sources and allow Cape's word fallback."
  (setq-local completion-at-point-functions
              (mapcar (lambda (capf)
                        (if (eq capf #'comint-completion-at-point)
                            #'nam/agent-shell-comint-capf
                          capf))
                      completion-at-point-functions))
  (nam/completion-preview-setup))

(with-eval-after-load 'agent-shell
  (define-key agent-shell-mode-map (kbd "TAB") #'nam/agent-shell-tab)
  (define-key agent-shell-mode-map (kbd "<tab>") #'nam/agent-shell-tab)
  (add-hook 'agent-shell-mode-hook #'nam/agent-shell-completion-setup 90))

(use-package completion-preview
  :ensure nil
  :demand t
  :custom
  (completion-preview-idle-delay 0.2)
  :config
  ;; Leave TAB to the major mode (indentation in code, folding in Org).
  (define-key completion-preview-active-mode-map (kbd "TAB") nil)
  (define-key completion-preview-active-mode-map (kbd "<tab>") nil)
  (define-key completion-preview-active-mode-map (kbd "RET") #'completion-preview-insert)
  (define-key completion-preview-active-mode-map (kbd "<return>") #'completion-preview-insert)
  (define-key completion-preview-active-mode-map (kbd "M-i") #'completion-preview-insert)
  (add-to-list 'completion-preview-commands #'org-self-insert-command)
  (add-hook 'completion-preview-inhibit-functions #'nam/completion-preview-inhibit-for-popup)
  (add-hook 'completion-preview-inhibit-functions #'nam/completion-preview-inhibit-for-agent-output)
  (add-hook 'corfu-mode-hook #'nam/completion-preview-setup)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer (nam/completion-preview-setup))))

(defvar-local nam/completion-major-mode-capf nil
  "Native completion provider retained while a language server is active.")

(defun nam/completion-select-source ()
  "Use one code/word provider, plus independent file completion.
Prefer Eglot/LSP, then the major mode's provider, then dabbrev."
  (when (and (not (derived-mode-p 'LaTeX-mode 'latex-mode))
             (derived-mode-p 'prog-mode 'text-mode 'comint-mode
                             'eshell-mode 'agent-shell-mode))
    (let* ((eglot (bound-and-true-p eglot--managed-mode))
           (lsp (or (bound-and-true-p lsp-managed-mode)
                    (bound-and-true-p lsp-completion-mode)))
           (native (seq-find
                    (lambda (capf)
                      (not (memq capf '(t cape-file cape-dabbrev cape-dict cape-emoji
                                         eglot-completion-at-point
                                         lsp-completion-at-point))))
                    completion-at-point-functions)))
      (when native
        (setq nam/completion-major-mode-capf native))
      ;; Preserve Eglot's insertion edits when labels include "name : type".
      (when eglot
        (setq-local orderless-expand-substring nil))
      (setq-local completion-at-point-functions
                  (list #'cape-file
                        (cond (eglot #'eglot-completion-at-point)
                              (lsp #'lsp-completion-at-point)
                              (nam/completion-major-mode-capf)
                              (t #'cape-dabbrev)))))))

(use-package cape
  :ensure t
  :demand t
  :config
  (setq-default completion-at-point-functions '(cape-file cape-dabbrev))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'agent-shell-mode)
        (nam/agent-shell-completion-setup))
      (nam/completion-select-source)))
  ;; Run after the major mode has installed its own completion functions.
  (add-hook 'after-change-major-mode-hook #'nam/completion-select-source 90)
  (add-hook 'lsp-managed-mode-hook #'nam/completion-select-source 90)
  (add-hook 'lsp-completion-mode-hook #'nam/completion-select-source 90)
  (with-eval-after-load 'eglot
    ;; Preserve Orderless matching now that Eglot keeps its own category.
    (setf (alist-get 'styles
                     (alist-get 'eglot-capf completion-category-overrides))
          '(orderless basic))
    (add-hook 'eglot-managed-mode-hook #'nam/completion-select-source 90)))
