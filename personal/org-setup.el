;;; -*- lexical-binding: nil; -*-
;;; 1. Portable paths and Prelude conflict resolution

(defvar my/org-directory (expand-file-name "org-files" "~")
  "Root directory for personal Org files.")

(defvar my/org-roam-directory
  (expand-file-name "org-roam" my/org-directory)
  "Directory containing Org-roam notes.")

(defvar my/org-agenda-file-candidates
  (mapcar (lambda (file) (expand-file-name file my/org-directory))
          '("inbox.org" "agenda.org" "projects.org"))
  "Potential agenda files, filtered to files present on the current host.")

;; A machine without the notes checkout should still start normally.
(defun my/org-roam-available-p ()
  "Return non-nil when the notes directory and built-in SQLite are available."
  (and (file-directory-p my/org-roam-directory)
       (fboundp 'sqlite-available-p)
       (sqlite-available-p)))

(defvar my/bibliography-files '("~/org-files/ref/My Library.bib")
  "Bibliography files used by Org citation tools.")

(setq my/bibliography-files
      (cl-remove-if-not #'file-readable-p
                        (mapcar #'expand-file-name my/bibliography-files)))

(with-eval-after-load 'crux
  (define-key prelude-mode-map (kbd "C-c n") nil))

;;; 2. Custom GTD Functions
(defun org-capture-inbox ()
  "Store link and open the inbox capture template."
  (interactive)
  (call-interactively 'org-store-link)
  (org-capture nil "i"))
(defun log-todo-next-creation-date (&rest ignore)
  "Log NEXT creation time in the property drawer under the key 'ACTIVATED'"
  (when (and (string= (org-get-todo-state) "NEXT")
             (not (org-entry-get nil "ACTIVATED")))
    (org-entry-put nil "ACTIVATED" (format-time-string "[%Y-%m-%d]"))))
(defun gtd-save-org-buffers ()
  "Save `org-agenda-files' buffers without user confirmation."
  (interactive)
  (message "Saving org-agenda-files buffers...")
  (save-some-buffers t (lambda ()
                         (when (member (buffer-file-name) org-agenda-files)
                           t)))
  (message "Saving org-agenda-files buffers... done"))

;;; 3. Org-Mode Core Settings & GTD
(use-package org
  :ensure t
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         ("C-c i" . org-capture-inbox)
         :map org-mode-map
         ("C-c o" . org-open-at-point))
  :hook ((org-capture-mode . delete-other-windows)
         (org-after-todo-state-change . log-todo-next-creation-date)
         ;; Disable windmove and flycheck (org-lint) locally in Org buffers
         (org-mode . (lambda ()
                       (windmove-mode -1)
                       (flycheck-mode -1)
                       (company-mode -1))))
  :config
  ;; Let windmove handle shift-arrows if Org doesn't need them (e.g., in text)
  (add-hook 'org-shiftup-final-hook #'windmove-up)
  (add-hook 'org-shiftleft-final-hook #'windmove-left)
  (add-hook 'org-shiftdown-final-hook #'windmove-down)
  (add-hook 'org-shiftright-final-hook #'windmove-right)

  ;; Base directories
  (setq org-directory my/org-directory)
  ;; Do not prompt about workstation-only agenda files on a fresh cluster.
  ;; Restart Emacs after copying those files to make them part of the agenda.
  (setq org-agenda-files
        (cl-remove-if-not #'file-exists-p my/org-agenda-file-candidates))

  ;; Explicitly load org-id to prevent link parsing errors
  (require 'org-id)
  (setq org-id-link-to-org-use-id t)

  ;; Todo Keywords & Visuals
  (setq org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "HOLD(h)" "|" "DONE(d)")))
  (setq org-log-done 'time)
  (setq org-hide-emphasis-markers t)
  ;; GTD Capture Templates
  (setq org-capture-templates
        `(("m" "Meeting" entry  (file+headline "~/org-files/agenda.org" "Future")
           ,(concat "* %? :meeting:\n"
                    "<%<%Y-%m-%d %a %H:00>>"))
          ("n" "Note" entry  (file "~/org-files/notes.org")
           ,(concat "* Note (%a)\n"
                    "/Entered on/ %U\n" "\n" "%?"))
          ("i" "Inbox" entry  (file "~/org-files/inbox.org")
           ,(concat "* TODO %?\n"
                    "/Entered on/ %U"))))
  ;; GTD Refile Config
  (setq org-refile-targets '(("agenda.org" :maxlevel . 9)
                             ("projects.org" :maxlevel . 9)
                             ("inbox.org" :maxlevel . 9)))
  (setq org-refile-use-outline-path 'file)
  (setq org-refile-allow-creating-parent-nodes 'confirm)
  (setq org-outline-path-complete-in-steps nil)

  ;; Auto-save after refile
  (advice-add 'org-refile :after (lambda (&rest _) (gtd-save-org-buffers)))
  ;; GTD Agenda Custom Commands & Visuals
  (setq org-agenda-hide-tags-regexp ".")
  (setq org-agenda-prefix-format
        '((agenda . " %i %-12:c%?-12t% s")
          (todo   . " %i %-12:c")
          (tags   . " %i %-12:c")
          (search . " %i %-12:c")))
  (setq org-agenda-custom-commands
        '(("g" "Get Things Done (GTD)"
           ((agenda ""
                    ((org-agenda-skip-function
                      '(org-agenda-skip-entry-if 'deadline))
                     (org-agenda-span 'day)
                     (org-deadline-warning-days 0)
                     (org-agenda-overriding-header "Today's Schedule\n")))
            (todo "NEXT"
                  ((org-agenda-prefix-format "  %i %-12:c [%e] ")
                   (org-agenda-overriding-header "\nNext Actions\n")))
            (agenda nil
                    ((org-agenda-entry-types '(:deadline))
                     (org-agenda-format-date "")
                     (org-deadline-warning-days 14)
                     (org-agenda-skip-function
                      '(org-agenda-skip-entry-if 'nottodo '("NEXT" "TODO")))
                     (org-agenda-overriding-header "\nUpcoming Deadlines\n")))
            (tags-todo "inbox"
                       ((org-agenda-prefix-format "  %?-12t% s")
                        (org-agenda-overriding-header "\nInbox\n")))
            (tags "CLOSED>=\"<today>\""
                  ((org-agenda-overriding-header "\nCompleted today\n"))))))))

;;; 4. Org Journal
(use-package org-journal
  :ensure t
  :after org)

;;; 4. Silence org-lint globally (Secondary Safety)
(with-eval-after-load 'flycheck
  (add-to-list 'flycheck-disabled-checkers 'org-lint))

;;; 5. Org-Roam Integration
(use-package org-roam
  :ensure t
  :if (my/org-roam-available-p)
  :custom
  (org-roam-directory my/org-roam-directory)
  (org-roam-completion-everywhere t)
  (org-roam-capture-templates
   '(("d" "default" plain "%?"
      :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n")
      :unnarrowed t)
     ("r" "bibliography reference" plain
      "* Summary\n* Interesting Points"
      :target (file+head "references/${citekey}.org"
                         "#+title: ${title}\n")
      :unnarrowed t)))
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         :map org-mode-map
         ("C-M-i" . completion-at-point))
  :config
  (org-roam-db-autosync-mode 1))

;;; 4. Ivy-Bibtex (The core search engine)
(use-package ivy-bibtex
  :ensure t
  :demand t
  :bind (("C-c b" . ivy-bibtex))
  :init
  (setq ivy-re-builders-alist '((ivy-bibtex . ivy--regex-ignore-order)
                                (t . ivy--regex-plus)))
  :config
  (setq bibtex-completion-bibliography my/bibliography-files
        bibtex-completion-pdf-field "file"
        bibtex-completion-pdf-open-function #'my/open-zotero-pdf)
  (define-key ivy-bibtex-extra-keymap (kbd "C-c o") #'ivy-dispatching-done))

;;; 4.5 Citar / Org-Cite
(use-package citar
  :ensure t
  :after org
  :custom
  (citar-bibliography my/bibliography-files)
  (org-cite-global-bibliography my/bibliography-files)
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  :config
  (require 'citar-org)
  (setq citar-file-open-functions
        '(("html" . citar-file-open-external)
          ("pdf" . my/open-zotero-pdf)
          (t . find-file))))

;;; 5. Org-Ref (Classic Citation Links & Hydras)
(use-package org-ref
  :ensure t
  :after ivy-bibtex
  :demand t
  :bind (:map org-mode-map
              ("C-c ]" . org-ref-insert-link)
              ("s-["   . org-ref-insert-link-hydra/body)
              :map bibtex-mode-map
              ("H-b"   . org-ref-bibtex-hydra/body))
  :init
  (require 'bibtex)
  (setq bibtex-autokey-year-length 4
        bibtex-autokey-name-year-separator "-"
        bibtex-autokey-year-title-separator "-"
        bibtex-autokey-titleword-separator "-"
        bibtex-autokey-titlewords 2
        bibtex-autokey-titlewords-stretch 1
        bibtex-autokey-titleword-length 5)
  ;; LaTeX export configuration
  (when (executable-find "latexmk")
    (setq org-latex-pdf-process (list "latexmk -shell-escape -bibtex -f -pdf %f")))
  :config
  (require 'org-ref-ivy)
  (require 'org-ref-arxiv)
  (require 'org-ref-scopus)
  (require 'org-ref-wos)
  ;; Hook up the Hydras for UI popups
  (setq org-ref-insert-link-function 'org-ref-insert-link-hydra/body
        org-ref-insert-cite-function 'org-ref-cite-insert-ivy
        org-ref-insert-label-function 'org-ref-insert-label-link
        org-ref-insert-ref-function 'org-ref-insert-ref-link
        org-ref-cite-onclick-function (lambda (_) (org-ref-citation-hydra/body))))

;;; 7. Org-Roam Bibtex (ORB)
(use-package org-roam-bibtex
  :ensure t
  :if (my/org-roam-available-p)
  :after org-roam
  :hook (org-roam-mode . org-roam-bibtex-mode)
  :init
  ;; Define the interface early so the warning goes away
  (setq orb-insert-interface 'ivy-bibtex)
  :config
  ;; Force load ivy-bibtex and ignore any remaining bad autoloads
  (require 'ivy-bibtex)
  (message "ORB loaded successfully"))


;;; 8. Citar (Modern Roam Linker)
(use-package citar-org-roam
  :ensure t
  :if (my/org-roam-available-p)
  :after (org-roam citar)
  :config
  (citar-register-notes-source 'orb-citar-source
                               (list :name "Org-Roam Notes"
                                     :category 'org-roam-node
                                     :items #'citar-org-roam--get-candidates
                                     :hasitems #'citar-org-roam-has-notes
                                     :open #'citar-org-roam-open-note
                                     :create #'orb-citar-edit-note
                                     :annotate #'citar-org-roam--annotate))
  (setq citar-notes-source 'orb-citar-source))
;;; ---------------------------------------------------------
;;; FINAL KEYBOARD OVERRIDES (The Last Word)
;;; ---------------------------------------------------------
;; This section runs AFTER all packages are defined.
;; It forces the keys to point to the functions without use-package's help.

;; 1. Tell Emacs these functions exist even if the packages are asleep
(autoload 'org-ref-insert-link "org-ref" "Insert org-ref link" t)

;; 2. Ruthlessly overwrite Org-mode's default map
(with-eval-after-load 'org
  (when (my/org-roam-available-p)
    (define-key org-mode-map (kbd "C-c z") #'orb-insert-link)
    (define-key org-mode-map (kbd "C-c b") #'orb-insert-link))
  (define-key org-mode-map (kbd "C-c o") #'org-open-at-point)
  ;; Steal C-c ] back from org-agenda-file-to-front
  (define-key org-mode-map (kbd "C-c ]") #'org-ref-insert-link))

;; Global override just in case you're not in an Org buffer
(with-eval-after-load 'prelude-mode
  (define-key prelude-mode-map (kbd "C-c o") nil))
(with-eval-after-load 'ivy
  (define-key ivy-minibuffer-map (kbd "C-c o") #'ivy-dispatching-done))
(when (my/org-roam-available-p)
  (global-set-key (kbd "C-c b") #'orb-insert-link)
  (global-set-key (kbd "C-c z") #'orb-insert-link))
;;; 7. Visual Styling (Org Modern & Fonts)
(use-package org-modern
  :ensure t
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))

(defun my/org-font-setup ()
  "Set face attributes for Org levels."
  (set-face-attribute 'org-level-1 nil :weight 'bold :height 1.728)
  (set-face-attribute 'org-level-2 nil :weight 'bold :height 1.44)
  (set-face-attribute 'org-level-3 nil :weight 'bold :height 1.2)
  (set-face-attribute 'org-document-title nil :height 2.074 :inherit 'org-level-8))
(add-hook 'org-mode-hook #'my/org-font-setup)



;;; 8. Performance & Stability
(with-eval-after-load 'org
  (setq org-element-use-cache t)
  ;; Keep nil to prevent "Wrong type argument: number-or-marker-p" AST crashes
  (setq org-element-cache-persistent nil)
  (setq org-fold-core-style 'overlays))



;;; 9. Set GTD Agenda as Startup Screen
(setq inhibit-startup-screen t)
(setq org-agenda-window-setup 'only-window)
(when (and (not (daemonp)) org-agenda-files)
  ;; Daemons have no startup frame and fresh cluster hosts may have no agenda
  ;; files, so only create the agenda when an interactive startup can use it.
  (setq initial-buffer-choice
        (lambda ()
          (org-agenda nil "g")
          (delete-other-windows)
          (get-buffer "*Org Agenda*"))))
(with-eval-after-load 'org-agenda
  (define-key org-agenda-mode-map (kbd "g")
              (lambda ()
                (interactive)
                (org-agenda-redo)
                (goto-char (point-min))
                (recenter 0))))

(use-package org-download
  :ensure t
  :after org)

;; Drag-and-drop to `dired`
(add-hook 'dired-mode-hook 'org-download-enable)

(when (and (executable-find "latex") (executable-find "dvisvgm"))
  (setq org-preview-latex-default-process 'dvisvgm)) ;No blur when scaling

(defun my/text-scale-adjust-latex-previews ()
  "Adjust the size of latex preview fragments when changing the
buffer's text scale."
  (pcase major-mode
    ('latex-mode
     (dolist (ov (overlays-in (point-min) (point-max)))
       (if (eq (overlay-get ov 'category)
               'preview-overlay)
           (my/text-scale--resize-fragment ov))))
    ('org-mode
     (dolist (ov (overlays-in (point-min) (point-max)))
       (if (eq (overlay-get ov 'org-overlay-type)
               'org-latex-overlay)
           (my/text-scale--resize-fragment ov))))))

(defun my/text-scale--resize-fragment (ov)
  (overlay-put
   ov 'display
   (cons 'image
         (plist-put
          (cdr (overlay-get ov 'display))
          :scale (+ 1.0 (* 0.25 text-scale-mode-amount))))))

(add-hook 'text-scale-mode-hook #'my/text-scale-adjust-latex-previews)
(when (executable-find "latexmk")
  (setq org-latex-pdf-process (list "latexmk -shell-escape -bibtex -f -pdf %f")))

;; imenu
(setq org-imenu-depth 7)
(add-hook 'org-mode-hook #'imenu-add-menubar-index)
(add-hook 'org-mode-hook (lambda () (setq-local imenu-auto-rescan t)))


(require 'org-habit)

(use-package org-timegrid
  :ensure t
  :bind ("C-c G" . org-timegrid-week)
  ;; The SVG header has no line-number gutter; keep its columns aligned.
  :hook (org-timegrid-mode . (lambda () (display-line-numbers-mode -1)))
  :init
  (setq org-timegrid-org-capture-file
        (expand-file-name "agenda.org" my/org-directory)
        org-timegrid-org-tag-color-alist
        '(("work" . indigo) ("personal" . green)))
  :config
  (require 'org-timegrid-org))

(use-package org-timegrid-agenda
  :ensure nil
  :after org-agenda
  :config
  (org-timegrid-agenda-mode 1))
