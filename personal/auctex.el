;;; -*- lexical-binding: nil; -*-
;;; auctex.el --- Personal AUCTeX config for Prelude

;; Packages
(prelude-require-package 'auctex)
(prelude-require-package 'company-reftex)

;; ----------------------------
;; Company completion for LaTeX
;; ----------------------------

(defun my-latex-company-setup ()
  "Set up Company completion for AUCTeX + RefTeX."
  (require 'company)
  (require 'company-reftex)

  ;; Make sure company is active in LaTeX buffers.
  (company-mode 1)

  ;; LaTeX-local completion backends.
  (setq-local company-backends
              '((company-reftex-citations
                 company-reftex-labels
                 company-capf
                 company-dabbrev-code)
                company-files
                company-dabbrev)))

(defun my-latex-keybindings ()
  "Personal keybindings for LaTeX buffers."
  ;; C-c C-g = same as C-c C-v, but easier to remember as “go to PDF”.
  (local-set-key (kbd "C-c C-g") #'TeX-view))

(defun my-latex-flyspell-setup ()
  "Enable LaTeX spell checking only when a spell checker is installed."
  (require 'ispell)
  (when-let* ((program (or (executable-find ispell-program-name)
                          (cl-some #'executable-find '("aspell" "hunspell" "ispell")))))
    (setq ispell-program-name program)
    (flyspell-mode 1)))

;; ----------------------------
;; AUCTeX
;; ----------------------------

(use-package tex
  :ensure auctex
  :defer t
  :mode ("\\.tex\\'" . LaTeX-mode)
  :hook ((LaTeX-mode . visual-line-mode)
         (LaTeX-mode . my-latex-flyspell-setup)
         (LaTeX-mode . LaTeX-math-mode)
         (LaTeX-mode . turn-on-reftex)
         (LaTeX-mode . my-latex-company-setup)
         (LaTeX-mode . my-latex-keybindings))
  :config
  ;; Basic AUCTeX behavior.
  (setq TeX-auto-save t
        TeX-parse-self t
        TeX-save-query nil)

  ;; Build PDFs by default.
  (setq-default TeX-PDF-mode t)

  ;; Ask for master file once per project.
  ;; Useful for multi-file LaTeX projects.
  (setq-default TeX-master nil)

  ;; Better RefTeX integration with AUCTeX.
  (setq reftex-plug-into-AUCTeX t)

  ;; Optional fallback if RefTeX cannot find your .bib automatically.
  ;; Uncomment and edit if needed.
  ;; (setq reftex-default-bibliography
  ;;       '("hotnets24-template.bib"))

  ;; ----------------------------
  ;; SyncTeX / source correlation
  ;; ----------------------------

  (setq TeX-source-correlate-mode t
        TeX-source-correlate-method 'synctex
        TeX-source-correlate-start-server t)

  ;; ----------------------------
  ;; Prefer Zathura, then an available system PDF viewer
  ;; ----------------------------

  (cond
   ((executable-find "zathura")
    (setq TeX-view-program-selection '((output-pdf "Zathura")))
    (add-to-list 'TeX-view-program-list
                 '("Zathura"
                   ("zathura"
                    (mode-io-correlate
                     " --synctex-forward %n:0:%b -x \"emacsclient --no-wait +%{line} %{input}\"")
                    " %o"))))
   ((or (and (eq system-type 'darwin) (executable-find "open"))
        (and (eq system-type 'gnu/linux) (executable-find "xdg-open")))
    (let ((program (if (eq system-type 'darwin) "open" "xdg-open")))
      (add-to-list 'TeX-view-program-list
                   (list "System PDF viewer" (concat program " %o")))
      (setq TeX-view-program-selection '((output-pdf "System PDF viewer"))))))

  ;; ----------------------------
  ;; Use latexmk as default command
  ;; ----------------------------

  ;; latexmk automatically runs:
  ;; LaTeX -> BibTeX/Biber if needed -> LaTeX -> LaTeX
  (when (executable-find "latexmk")
    (add-to-list 'TeX-command-list
                 '("LatexMk"
                   "latexmk -pdf -interaction=nonstopmode -file-line-error -synctex=1 %(output-dir) %s"
                   TeX-run-TeX nil t
                   :help "Run latexmk on file"))

    ;; Make C-c C-c default to LatexMk.
    (setq TeX-command-default "LatexMk")))

;;; auctex.el ends here
