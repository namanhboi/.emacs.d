;;; -*- lexical-binding: nil; -*-
;;; PDF handling

(defcustom my/pdf-viewer-program nil
  "External PDF viewer, or nil to find an available viewer automatically."
  :type '(choice (const :tag "Find automatically" nil) string))

(defun my/pdf-viewer-executable ()
  "Return an available PDF viewer, or nil on hosts without one."
  (if my/pdf-viewer-program
      (executable-find my/pdf-viewer-program)
    (or (executable-find "zathura")
        (and (eq system-type 'darwin) (executable-find "open"))
        (and (eq system-type 'gnu/linux) (executable-find "xdg-open")))))

(defcustom my/zotero-storage-directory "~/Zotero/storage"
  "Directory where Zotero stores managed attachment files."
  :type 'directory)

(defun my/open-pdf-with-zathura (&optional file)
  "Open FILE, or the current buffer's file, with an available PDF viewer."
  (interactive)
  (let* ((pdf-file (expand-file-name (or file buffer-file-name)))
         (program (or (my/pdf-viewer-executable)
                      (user-error "No external PDF viewer is available"))))
    (start-process "pdf-viewer" nil program pdf-file)
    (message "Opened %s with %s" (abbreviate-file-name pdf-file)
             (file-name-nondirectory program))
    (when (and buffer-file-name
               (string-equal (file-truename pdf-file)
                             (file-truename buffer-file-name)))
      (let ((buffer (current-buffer)))
        (run-at-time 0 nil
                     (lambda (buf)
                       (when (buffer-live-p buf)
                         (kill-buffer buf)))
	                     buffer)))))

(defun my/zotero-storage-key-from-file (file)
  "Return Zotero attachment key for FILE when it is in Zotero storage."
  (let* ((pdf-file (file-truename (expand-file-name file)))
         (storage-dir (file-name-as-directory
                       (file-truename
                        (expand-file-name my/zotero-storage-directory)))))
    (when (and (file-directory-p storage-dir)
               (string-prefix-p storage-dir pdf-file))
      (car (split-string (file-relative-name pdf-file storage-dir) "/" t)))))

(defun my/open-url-externally (url)
  "Open URL with the desktop URL handler."
  (if-let* ((program (if (eq system-type 'darwin)
                        (executable-find "open")
                      (executable-find "xdg-open"))))
      (start-process "open-url" nil program url)
    (browse-url url)))

(defun my/open-zotero-pdf (&optional file)
  "Open Zotero-managed FILE in Zotero's PDF reader.
Fall back to `my/open-pdf-with-zathura' for PDFs outside Zotero storage."
  (interactive)
  (let ((pdf-file (or file buffer-file-name)))
    (unless pdf-file
      (error "No PDF file given"))
    (if-let* ((_ (or (executable-find "zotero")
                    (and (eq system-type 'darwin)
                         (or (file-directory-p "/Applications/Zotero.app")
                             (file-directory-p
                              (expand-file-name "~/Applications/Zotero.app"))))))
              (key (my/zotero-storage-key-from-file pdf-file)))
        (let ((url (format "zotero://open-pdf/library/items/%s" key)))
          (my/open-url-externally url)
          (message "Opened %s in Zotero" (abbreviate-file-name pdf-file)))
      (my/open-pdf-with-zathura pdf-file))))

(when (my/pdf-viewer-executable)
  (add-to-list 'auto-mode-alist '("\\.pdf\\'" . my/open-pdf-with-zathura)))

(with-eval-after-load 'bibtex-completion
  (setq bibtex-completion-pdf-open-function #'my/open-zotero-pdf))
