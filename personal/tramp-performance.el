;;; tramp-performance.el --- Conservative TRAMP performance settings -*- lexical-binding: t; -*-

;;; Commentary:
;; Settings adapted from
;; https://coredumped.dev/2025/06/18/making-tramp-go-brrrr./
;;
;; Keep this focused on TRAMP's supported knobs.  In particular, do not add
;; indefinite project/VC advice caches: stale remote repository state is more
;; expensive than the calls those caches avoid.

;;; Code:

;; Avoid remote round trips for lock files and visited-file auto-saving.
;; Ordinary Emacs auto-save files are unaffected.
(setq remote-file-name-inhibit-locks t
      remote-file-name-inhibit-auto-save-visited t)

(with-eval-after-load 'tramp
  ;; Preserve each host's login PATH, including virtualenvs and course tools.
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path)

  ;; Inline transfer is faster for small and medium files.  Above 1 MiB,
  ;; permit TRAMP to use its out-of-band copy method.
  (setq tramp-copy-size-limit (* 1024 1024)
        tramp-use-scp-direct-remote-copying t
        tramp-verbose 2)

  ;; Remote compilation normally disables SSH connection sharing.  Reuse the
  ;; already configured ControlMaster connection instead.
  (with-eval-after-load 'compile
    (remove-hook 'compilation-mode-hook
                 #'tramp-compile-disable-ssh-controlmaster-options)))

(with-eval-after-load 'magit
  ;; Avoid costly automatic refreshes in remote repositories.
  (setq magit-commit-show-diff nil
        magit-branch-direct-configure nil
        magit-refresh-status-buffer nil))

(provide 'tramp-performance)
;;; tramp-performance.el ends here
