;;; projects.el --- Built-in project management -*- lexical-binding: t; -*-

(require 'project)

;; Also apply the migration when reloading this file in an existing session.
(setq prelude-projectile nil)
(when (bound-and-true-p projectile-mode)
  (projectile-mode -1))
(remove-hook 'project-find-functions #'project-projectile)

;; Recognize explicit project markers, including existing Projectile roots.
(dolist (marker '(".project" ".projectile"))
  (add-to-list 'project-vc-extra-root-markers marker))

;; Match the previous switch-project action: go straight to the file picker.
(setq project-switch-commands #'project-find-file
      project-mode-line t)

;; Keep the familiar Prelude prefixes as aliases for project.el commands.
;; The old terminal submenu lives only in these aliases, leaving native
;; `C-x p x' available for `project-execute-extended-command'.
(defvar nam/project-command-map (make-sparse-keymap)
  "Project commands with the former terminal submenu.")
(set-keymap-parent nam/project-command-map project-prefix-map)
(define-key nam/project-command-map (kbd "x") (make-sparse-keymap))
(define-key nam/project-command-map (kbd "x G") #'nam/project-ghostel)
(define-key nam/project-command-map (kbd "x h") #'nam/project-ghostel)
(global-set-key (kbd "C-c p") nam/project-command-map)
(when prelude-super-keybindings
  (global-set-key (kbd "s-p") nam/project-command-map))
;; Remove bindings from a Prelude mode map created before the migration.
(define-key prelude-mode-map (kbd "C-c p") nil)
(define-key prelude-mode-map (kbd "s-p") nil)

;;; projects.el ends here
