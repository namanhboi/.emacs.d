;;; prelude-rust.el --- Emacs Prelude: Rust programming support.

;;; Commentary:

;; Prelude configuration for Rust using rust-mode or rust-ts-mode.

;;; Code:

(require 'prelude-programming)

;; Use Eglot as Prelude's LSP client.
(setq prelude-lsp-client 'eglot)

;; You may need to install:
;; * rustc
;; * cargo
;; * rustfmt
;; * rust-analyzer

(defun nam/rust-buffer-p ()
  "Return non-nil when the current buffer is using a Rust major mode."
  (derived-mode-p 'rust-mode 'rust-ts-mode))

(add-to-list 'super-save-predicates
             (lambda () (not (nam/rust-buffer-p))))

;; ---------------------------------------------------------------------
;; Eglot + rust-analyzer
;; ---------------------------------------------------------------------

(use-package eglot
  :ensure nil
  :defer t
  :config
  (add-to-list 'eglot-server-programs
               '((rust-mode rust-ts-mode) .
                 ("rust-analyzer"
                  :initializationOptions
                  (:check (:command "clippy")
                   :cargo (:features "all")
                   :procMacro (:enable t))))))

(defun nam/rust-format-buffer-on-save ()
  "Format Rust buffer with Eglot before saving."
  (when (and (nam/rust-buffer-p)
             (bound-and-true-p eglot--managed-mode))
    (eglot-format-buffer)))

(defun nam/rust-run-flycheck-rust-setup ()
  "Run flycheck-rust-setup for Rust buffers."
  (when (nam/rust-buffer-p)
    (with-demoted-errors "Error in Rust Flycheck setup: %S"
      (nam/rust-set-safe-flycheck-defaults)
      (require 'flycheck-rust)
      (flycheck-rust-setup))))

(defun nam/rust-set-safe-flycheck-defaults ()
  "Avoid Flycheck forcing Cargo to check a library target by default."
  (setq-local flycheck-rust-crate-type nil)
  (setq-local flycheck-rust-binary-name nil))

(defvar-local nam/rust-flycheck-was-enabled nil
  "Whether Flycheck was already enabled before Rust defaults ran.")

(defun prelude-rust-mode-defaults ()
  "Default Rust mode configuration."
  ;; Let Eglot/rust-analyzer handle formatting.
  (setq rust-format-on-save nil)

  ;; Flycheck defaults this to \"lib\", which breaks binary-only Cargo
  ;; packages before flycheck-rust has inferred the concrete target.
  (nam/rust-set-safe-flycheck-defaults)

  ;; `global-flycheck-mode' turns Flycheck on from `prog-mode-hook',
  ;; before `rust-mode-hook' or `rust-ts-mode-hook' runs.  Restart it
  ;; after the Rust-specific target setup below so the first Cargo check
  ;; does not run with Flycheck's default library target.
  (setq-local nam/rust-flycheck-was-enabled
              (bound-and-true-p flycheck-mode))
  (when (bound-and-true-p flycheck-mode)
    (flycheck-mode -1))

  ;; Rust files start with #![...] inner attributes, which can look like
  ;; a shebang to Emacs. Prevent auto-chmod on save.
  (remove-hook 'after-save-hook
               'executable-make-buffer-file-executable-if-script-p
               t)

  ;; CamelCase aware editing operations.
  (subword-mode +1)

  ;; Start rust-analyzer through Prelude's Eglot setup.
  (prelude-lsp-enable)

  ;; Flycheck Rust is useful, but it must not prevent Eglot startup.
  (nam/rust-run-flycheck-rust-setup)

  (when nam/rust-flycheck-was-enabled
    (flycheck-mode +1))

  ;; Format with rust-analyzer on save.
  (add-hook 'before-save-hook #'nam/rust-format-buffer-on-save nil t))

;; ---------------------------------------------------------------------
;; rust-mode
;; ---------------------------------------------------------------------

(use-package rust-mode
  :ensure t
  :hook (rust-mode . (lambda ()
                       (run-hooks 'prelude-rust-mode-hook)))
  :config
  (let ((dot-cargo-bin (expand-file-name "~/.cargo/bin/")))
    (setq rust-rustfmt-bin (concat dot-cargo-bin "rustfmt")
          rust-cargo-bin (concat dot-cargo-bin "cargo"))))

;; Loading `rust-ts-mode' without its grammar emits a warning during every
;; startup.  Keep the conventional Rust mode available on minimal hosts and
;; enable the Tree-sitter variant automatically once its grammar is installed.
(when (and (fboundp 'treesit-ready-p)
           (treesit-ready-p 'rust t))
  (use-package rust-ts-mode
    :ensure t
    :hook (rust-ts-mode . (lambda ()
                            (run-hooks 'prelude-rust-mode-hook)))))

;; ---------------------------------------------------------------------
;; Cargo commands
;; ---------------------------------------------------------------------

(use-package cargo
  :ensure t
  :hook ((rust-mode rust-ts-mode) . cargo-minor-mode))

;; ---------------------------------------------------------------------
;; Flycheck Rust integration
;; ---------------------------------------------------------------------

(use-package flycheck-rust
  :ensure t
  :after flycheck
  :defer t)

(with-eval-after-load 'flycheck
  ;; Flycheck's built-in Rust checker defaults this to \"lib\", which makes
  ;; binary-only packages fail with \"no library targets found\" before
  ;; flycheck-rust has a chance to infer the package target.
  (setq-default flycheck-rust-crate-type nil)
  (setq-default flycheck-rust-binary-name nil)
  (add-hook 'flycheck-mode-hook
            #'nam/rust-run-flycheck-rust-setup)
  (add-hook 'flycheck-before-syntax-check-hook
            #'nam/rust-run-flycheck-rust-setup))

;; ---------------------------------------------------------------------
;; RON files
;; ---------------------------------------------------------------------

(use-package ron-mode
  :ensure t
  :defer t)

(setq prelude-rust-mode-hook 'prelude-rust-mode-defaults)

(provide 'prelude-rust)
;;; prelude-rust.el ends here
