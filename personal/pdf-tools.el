;;; PDF handling

(defcustom my/pdf-viewer-program "zathura"
  "External program used to open PDF files."
  :type 'string)

(defcustom my/zotero-storage-directory "~/Zotero/storage"
  "Directory where Zotero stores managed attachment files."
  :type 'directory)

(defun my/open-pdf-with-zathura (&optional file)
  "Open FILE, or the current buffer's file, in Zathura."
  (interactive)
  (let* ((pdf-file (expand-file-name (or file buffer-file-name)))
         (program (or (executable-find my/pdf-viewer-program)
                      (error "Cannot find %s in PATH" my/pdf-viewer-program))))
    (start-process "zathura" nil program pdf-file)
    (message "Opened %s in Zathura" (abbreviate-file-name pdf-file))
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
    (when (string-prefix-p storage-dir pdf-file)
      (car (split-string (file-relative-name pdf-file storage-dir) "/" t)))))

(defun my/open-url-externally (url)
  "Open URL with the desktop URL handler."
  (if-let ((xdg-open (executable-find "xdg-open")))
      (start-process "open-url" nil xdg-open url)
    (browse-url url)))

(defun my/open-zotero-pdf (&optional file)
  "Open Zotero-managed FILE in Zotero's PDF reader.
Fall back to `my/open-pdf-with-zathura' for PDFs outside Zotero storage."
  (interactive)
  (let ((pdf-file (or file buffer-file-name)))
    (unless pdf-file
      (error "No PDF file given"))
    (if-let ((key (my/zotero-storage-key-from-file pdf-file)))
        (let ((url (format "zotero://open-pdf/library/items/%s" key)))
          (my/open-url-externally url)
          (message "Opened %s in Zotero" (abbreviate-file-name pdf-file)))
      (my/open-pdf-with-zathura pdf-file))))

(add-to-list 'auto-mode-alist '("\\.pdf\\'" . my/open-pdf-with-zathura))

(with-eval-after-load 'bibtex-completion
  (setq bibtex-completion-pdf-open-function #'my/open-zotero-pdf))
