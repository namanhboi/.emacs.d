(use-package ghostel
  :vc (:url "https://github.com/dakra/ghostel"
            :lisp-dir "lisp"
            :rev :newest)
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
