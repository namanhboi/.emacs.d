(use-package ghostel
  :vc (:url "https://github.com/dakra/ghostel"
            :lisp-dir "lisp"
            :rev :newest)
  :init
  ;; Let Ghostel use its built-in TRAMP process, shell-discovery, and
  ;; temporary terminfo setup.  Enabling integration also makes
  ;; `ghostel-ssh-install-terminfo' effective through its `auto' default.
  (setq ghostel-tramp-shell-integration t)
  (setq ghostel-tramp-shells
        '(("ssh" login-shell)          ; auto-detect via getent
          ("sshx" login-shell)
          ("scp" login-shell)
          ("docker" "/bin/sh")))       ; fixed shell for containers
  :commands (ghostel
             ghostel-project
             ghostel-other
             ghostel-next
             ghostel-previous
             ghostel-list-buffers
             ghostel-project-next
             ghostel-project-previous
             ghostel-project-list-buffers))

(defun projectile-run-ghostel (&optional arg)
  "Invoke `ghostel' from the current Projectile project root.

Switch to the project-specific Ghostel buffer if it already exists.
With prefix ARG, pass ARG through to `ghostel'."
  (interactive "P")
  (let* ((project (file-name-as-directory (projectile-acquire-root)))
         (default-directory project)
         (ghostel-buffer-name (projectile-generate-process-name
                               "ghostel" nil project)))
    (ghostel arg)))

(with-eval-after-load 'projectile
  (define-key projectile-command-map (kbd "x G") #'projectile-run-ghostel)
  (define-key projectile-command-map (kbd "x h") #'projectile-run-ghostel))

(global-set-key (kbd "C-x p h") #'projectile-run-ghostel)
;; Default configuration
