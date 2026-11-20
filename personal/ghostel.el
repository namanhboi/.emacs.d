;;; -*- lexical-binding: nil; -*-
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

(require 'project)

(defun nam/project-ghostel (&optional arg)
  "Invoke `ghostel' from the current project root.

Switch to the project-specific Ghostel buffer if it already exists.
With prefix ARG, pass ARG through to `ghostel'."
  (interactive "P")
  (let* ((project (project-current t))
         (root (file-name-as-directory (expand-file-name (project-root project))))
         (default-directory root)
         (name (format "*ghostel %s*" (project-name project)))
         (existing (get-buffer name))
         ;; Preserve existing terminal names and distinguish equal project names.
         (ghostel-buffer-name
          (if (and existing
                   (not (equal (buffer-local-value 'default-directory existing)
                               root)))
              (format "*ghostel %s*" (abbreviate-file-name root))
            name)))
    (ghostel arg)))

(define-key project-prefix-map (kbd "h") #'nam/project-ghostel)
;; Default configuration
