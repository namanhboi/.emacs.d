;;; tramp-performance.el --- Faster TRAMP for remote development -*- lexical-binding: t; -*-

;; Put this file in ~/.emacs.d/personal/tramp-performance.el when using Prelude.
;; Do NOT name it "tramp.el": that would shadow Emacs's built-in tramp.el.
;;
;; This configuration is aimed at Git-backed SSH/SCP remote projects.  It keeps
;; project.el and Projectile usable over TRAMP while avoiding repeated remote
;; file probes.  Some options have explicit tradeoffs; read the comments below.

;;; Code:

(require 'cl-lib)

(defgroup my/tramp-performance nil
  "Performance settings for remote editing through TRAMP."
  :group 'tramp)

(defcustom my/tramp-default-method "scp"
  "Default TRAMP transfer method for remote file names using /-: syntax.

Use \"scp\" for a conservative external transfer method.  On Emacs 30.2 or
later, you may test \"rsync\" for faster incremental saves.  Explicit remote
paths such as /ssh:host:/path ignore this option."
  :type 'string
  :group 'my/tramp-performance)

(defcustom my/tramp-use-direct-async-processes nil
  "Whether to enable TRAMP direct async processes over SSH/SCP.

This can greatly speed up Magit and other asynchronous remote subprocesses.
Keep it nil when you need Eglot or lsp-mode in remote buffers unless you have
tested that your language server starts correctly: direct async processes can
break LSP server startup over TRAMP."
  :type 'boolean
  :group 'my/tramp-performance)

(defcustom my/tramp-use-controlmaster-for-compilation nil
  "Whether to re-enable shared SSH connections for remote compilation.

This reproduces an optimization from the article, but is nil by default
because TRAMP deliberately disables connection sharing for compilation:
concurrent use of the OpenSSH control socket can block Emacs.  Turn this on
only after testing remote `compile' on your hosts."
  :type 'boolean
  :group 'my/tramp-performance)

(defcustom my/tramp-inhibit-remote-lock-files t
  "Whether to avoid creating lock files for remote files.

This removes remote filesystem round trips.  Set it to nil if more than one
Emacs session may edit the same remote files, since lock-file warnings will no
longer protect you from conflicting edits."
  :type 'boolean
  :group 'my/tramp-performance)

(defcustom my/tramp-disable-auto-save-visited-on-remote t
  "Whether `auto-save-visited-mode' should avoid writing remote files.

This does not disable ordinary local auto-save copies; it prevents visited-file
auto-saving from repeatedly writing through TRAMP."
  :type 'boolean
  :group 'my/tramp-performance)

(defcustom my/tramp-memoize-magit-roots t
  "Whether to memoize remote `magit-toplevel' results."
  :type 'boolean
  :group 'my/tramp-performance)

(defcustom my/tramp-memoize-vc-git-roots t
  "Whether to memoize successful remote `vc-git-root' results."
  :type 'boolean
  :group 'my/tramp-performance)

(defcustom my/tramp-memoize-counsel-git-candidates t
  "Whether to memoize remote `counsel-git-cands' results, when Counsel is used."
  :type 'boolean
  :group 'my/tramp-performance)

;; ---------------------------------------------------------------------------
;; Low-cost global reductions
;; ---------------------------------------------------------------------------

;; You use Git projects; avoid remote probes for VC backends you do not use.
(setq vc-handled-backends '(Git))

;; These variables are implemented by file-name handlers and may be set before
;; TRAMP is loaded.
(when my/tramp-inhibit-remote-lock-files
  (setq remote-file-name-inhibit-locks t))

(when my/tramp-disable-auto-save-visited-on-remote
  (setq remote-file-name-inhibit-auto-save-visited t))

;; ---------------------------------------------------------------------------
;; Core TRAMP behavior
;; ---------------------------------------------------------------------------

(with-eval-after-load 'tramp
  ;; Use an external copy method for /-: paths.  To benefit from this when
  ;; entering paths explicitly, use /scp:host:/path rather than /ssh:host:/path.
  (setq tramp-default-method my/tramp-default-method

        ;; The article measured inline transfers as preferable until around
        ;; 2 MB and selected 1 MB as a conservative crossover.
        tramp-copy-size-limit (* 1024 1024)

        ;; Keep normal operation quiet; increase this temporarily for debugging.
        tramp-verbose 2

        ;; Helps only when copying files directly between two remote hosts.
        tramp-use-scp-direct-remote-copying t)

  ;; Intentionally do NOT set `remote-file-name-inhibit-cache' to nil.
  ;; Your build, Git, and experiment commands can modify remote files outside
  ;; Emacs, so unlimited TRAMP file-attribute caching could become stale.

  ;; Direct async substantially reduces subprocess setup overhead, but is
  ;; optional because it can conflict with remote Eglot/lsp-mode processes.
  (when my/tramp-use-direct-async-processes
    (connection-local-set-profile-variables
     'my/tramp-direct-async-process
     '((tramp-direct-async-process . t)))
    (dolist (protocol '("ssh" "scp"))
      (connection-local-set-profiles
       `(:application tramp :protocol ,protocol)
       'my/tramp-direct-async-process))))

;; ---------------------------------------------------------------------------
;; Compilation: available, but intentionally opt-in
;; ---------------------------------------------------------------------------

(defun my/tramp-enable-controlmaster-for-compilation ()
  "Re-enable SSH connection sharing for compilation when requested."
  (when my/tramp-use-controlmaster-for-compilation
    (remove-hook 'compilation-mode-hook
                 #'tramp-compile-disable-ssh-controlmaster-options)))

(with-eval-after-load 'tramp
  (with-eval-after-load 'compile
    (my/tramp-enable-controlmaster-for-compilation)))


;; ---------------------------------------------------------------------------
;; Repeated remote root/candidate queries from VC, Magit, and Counsel
;; ---------------------------------------------------------------------------

(defconst my/tramp--cache-miss (make-symbol "my/tramp--cache-miss")
  "Sentinel used to distinguish missing cached entries from cached nil values.")

(defvar my/tramp--project-current-cache (make-hash-table :test #'equal))
(defvar my/tramp--magit-toplevel-cache (make-hash-table :test #'equal))
(defvar my/tramp--vc-git-root-cache (make-hash-table :test #'equal))
(defvar my/tramp--counsel-git-cands-cache (make-hash-table :test #'equal))

(defun my/tramp--memoize-remote-call
    (cache remote-path cache-key original-function arguments &optional cache-nil)
  "Memoize ORIGINAL-FUNCTION over remote paths.

CACHE is a hash table.  REMOTE-PATH determines whether the call is remote.
CACHE-KEY identifies the call.  ARGUMENTS is applied to ORIGINAL-FUNCTION.
When CACHE-NIL is non-nil, cache nil results as well."
  (if (not (and (stringp remote-path)
                (file-remote-p remote-path)))
      (apply original-function arguments)
    (let ((cached (gethash cache-key cache my/tramp--cache-miss)))
      (if (not (eq cached my/tramp--cache-miss))
          cached
        (let ((value (apply original-function arguments)))
          (when (or value cache-nil)
            (puthash cache-key value cache))
          value)))))

;; Fallback for older project.el versions without built-in remote VC caching.
(defun my/tramp--cached-project-current
    (original-function &optional maybe-prompt directory)
  "Memoize remote `project-current' for older project.el versions."
  (let ((dir (or directory default-directory)))
    (my/tramp--memoize-remote-call
     my/tramp--project-current-cache dir (cons maybe-prompt dir)
     original-function (list maybe-prompt directory) t)))

(with-eval-after-load 'project
  (unless (boundp 'project-vc-cache-timeout)
    (unless (advice-member-p #'my/tramp--cached-project-current
                             'project-current)
      (advice-add 'project-current :around #'my/tramp--cached-project-current))))

(defun my/tramp--cached-vc-git-root (original-function file)
  "Memoize successful remote `vc-git-root' results."
  (let ((directory (file-name-directory file)))
    (my/tramp--memoize-remote-call
     my/tramp--vc-git-root-cache directory directory
     original-function (list file))))

(with-eval-after-load 'vc-git
  (when my/tramp-memoize-vc-git-roots
    (unless (advice-member-p #'my/tramp--cached-vc-git-root 'vc-git-root)
      (advice-add 'vc-git-root :around #'my/tramp--cached-vc-git-root))))

(defun my/tramp--cached-magit-toplevel
    (original-function &optional directory)
  "Memoize successful remote `magit-toplevel' results."
  (let ((dir (or directory default-directory)))
    (my/tramp--memoize-remote-call
     my/tramp--magit-toplevel-cache dir dir
     original-function (list directory))))

(with-eval-after-load 'magit
  ;; Reduce work performed by remote Magit commands.
  (setq magit-tramp-pipe-stty-settings 'pty
        magit-commit-show-diff nil
        magit-branch-direct-configure nil
        magit-refresh-status-buffer nil)

  (when my/tramp-memoize-magit-roots
    (unless (advice-member-p #'my/tramp--cached-magit-toplevel
                             'magit-toplevel)
      (advice-add 'magit-toplevel :around #'my/tramp--cached-magit-toplevel))))

(defun my/tramp--cached-counsel-git-cands (original-function directory)
  "Memoize successful remote `counsel-git-cands' results."
  (my/tramp--memoize-remote-call
   my/tramp--counsel-git-cands-cache directory directory
   original-function (list directory)))

(with-eval-after-load 'counsel
  (when (and my/tramp-memoize-counsel-git-candidates
             (fboundp 'counsel-git-cands))
    (unless (advice-member-p #'my/tramp--cached-counsel-git-cands
                             'counsel-git-cands)
      (advice-add 'counsel-git-cands :around
                  #'my/tramp--cached-counsel-git-cands))))


(provide 'tramp-performance)
;;; tramp-performance.el ends here
