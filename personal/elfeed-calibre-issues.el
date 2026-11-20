;;; elfeed-calibre-issues.el --- Completed Calibre issues in Elfeed -*- lexical-binding: t; -*-

;;; Commentary:
;; G imports completed Atlantic and Financial Times EPUBs from the Calibre
;; library.  RET opens an issue locally in nov-mode; no browser is launched.

;;; Code:

(use-package elfeed :ensure t :defer t)
(require 'sqlite nil t)
(require 'url-parse)
(require 'url-util)

(defcustom nam/elfeed-calibre-library (expand-file-name "~/Calibre Library")
  "Calibre library containing downloaded news issues."
  :type 'directory
  :group 'elfeed)

(defcustom nam/elfeed-calibre-include-backfills nil
  "Whether to include month-backfill collections alongside daily issues."
  :type 'boolean
  :group 'elfeed)

(defun nam/elfeed-calibre-available-p ()
  "Return non-nil when this host can read its local Calibre library."
  (and (fboundp 'sqlite-available-p)
       (sqlite-available-p)
       (file-readable-p
        (expand-file-name "metadata.db" nam/elfeed-calibre-library))))

(defconst nam/elfeed-calibre-issue-feeds
  '(("calibre://atlantic" :title "The Atlantic — Calibre issues"
     :no-update t :show-entry nam/elfeed-calibre-open-issue news atlantic issue)
    ("calibre://financial-times" :title "Financial Times — Calibre issues"
     :no-update t :show-entry nam/elfeed-calibre-open-issue news financial-times issue))
  "Local feeds backed by completed EPUBs in the Calibre library.")

(defun nam/elfeed-calibre-open-issue (url)
  "Open the local EPUB at URL inside Emacs."
  (let ((file (decode-coding-string
               (url-unhex-string (url-filename (url-generic-parse-url url)))
               'utf-8)))
    (unless (file-readable-p file)
      (user-error "Issue no longer exists; press G in Elfeed to refresh"))
    (require 'nov)
    (find-file file)
    (unless (derived-mode-p 'nov-mode)
      (nov-mode))))

(defun nam/elfeed-calibre-import-issues ()
  "Import completed Atlantic and FT EPUBs without starting Calibre.
Preserve read status, and remove issue entries whose EPUBs were deleted."
  (interactive)
  (let ((database (expand-file-name "metadata.db" nam/elfeed-calibre-library)))
    (when (nam/elfeed-calibre-available-p)
      (require 'elfeed-db)
      (condition-case err
          (let* ((connection (sqlite-open database t))
                 (rows (unwind-protect
                           (sqlite-select
                            connection
                            "SELECT b.id,b.uuid,b.title,b.path,d.name,b.pubdate,b.timestamp
                             FROM books b JOIN data d ON d.book=b.id
                             WHERE d.format='EPUB'
                             AND (b.title LIKE 'Financial Times%'
                                  OR b.title LIKE 'TheAtlantic.com%'
                                  OR b.title LIKE 'The Atlantic%')")
                         (sqlite-close connection)))
                 (entries nil)
                 (present (make-hash-table :test #'equal))
                 (obsolete nil))
            (elfeed-db-ensure)
            (dolist (row rows)
              (pcase-let* ((`(,book-id ,uuid ,title ,directory ,name ,pubdate ,timestamp) row)
                           (ft (string-match-p "\\`Financial Times\\(?: \\[\\|\\'\\)" title))
                           (atlantic (string-match-p
                                      "\\`\\(?:TheAtlantic\\.com\\|The Atlantic\\)\\(?: \\[\\|\\'\\)"
                                      title))
                           (feed-id (cond (ft "calibre://financial-times")
                                          (atlantic "calibre://atlantic")))
                           (file (expand-file-name
                                  (concat directory "/" name ".epub")
                                  nam/elfeed-calibre-library)))
                (when (and feed-id
                           (or nam/elfeed-calibre-include-backfills
                               (not (string-match-p "\\[Available articles," title)))
                           (file-readable-p file)
                           (> (file-attribute-size (file-attributes file)) 0))
                  (let ((id (cons (concat "calibre:" nam/elfeed-calibre-library)
                                  (or uuid (number-to-string book-id)))))
                    (puthash id t present)
                    (push
                     (elfeed-entry--create
                      :id id :feed-id feed-id :title title
                      :link (concat "file://"
                                    (mapconcat #'url-hexify-string
                                               (split-string file "/") "/"))
                      :date (or (ignore-errors (elfeed-float-time pubdate))
                                (ignore-errors (elfeed-float-time timestamp))
                                (float-time))
                      :content "<p>Downloaded Calibre issue. Open from the feed list with RET to read the local EPUB.</p>"
                      :content-type 'html
                      :tags (list 'unread 'news 'issue (if ft 'financial-times 'atlantic))
                      :meta (list :calibre-book-id book-id))
                     entries)))))
            (dolist (subscription nam/elfeed-calibre-issue-feeds)
              (let ((feed (elfeed-db-get-feed (car subscription))))
                (setf (elfeed-feed-url feed) (car subscription)
                      (elfeed-feed-title feed) (plist-get (cdr subscription) :title))))
            (elfeed-db-add entries)
            (maphash
             (lambda (id entry)
               (when (and (assoc (elfeed-entry-feed-id entry) nam/elfeed-calibre-issue-feeds)
                          (not (gethash id present)))
                 (push entry obsolete)))
             elfeed-db-entries)
            (elfeed-db-delete obsolete)
            (elfeed-db-save)
            (when (called-interactively-p 'interactive)
              (message "Imported %d completed Calibre issues" (length entries))))
        (error (message "Calibre issue import: %s" (error-message-string err)))))))

(defun nam/elfeed-calibre-fetch-issues (url callback)
  "Handle an explicit update of a local issue feed at URL using CALLBACK."
  (when (assoc url nam/elfeed-calibre-issue-feeds)
    (nam/elfeed-calibre-import-issues)
    (funcall callback :success)
    t))

(with-eval-after-load 'elfeed
  ;; Retire the previous per-article browser fetcher in a running session.
  (remove-hook 'elfeed-show-update-hook #'nam/elfeed-calibre-show)
  (define-key elfeed-show-mode-map (kbd "f") #'elfeed-show-fetch-link)
  (when (nam/elfeed-calibre-available-p)
    (dolist (feed nam/elfeed-calibre-issue-feeds)
      (setq elfeed-feeds (assoc-delete-all (car feed) elfeed-feeds))
      (add-to-list 'elfeed-feeds feed t))
    (clrhash elfeed-feed--meta-cache)
    (add-hook 'elfeed-update-init-hook #'nam/elfeed-calibre-import-issues t)
    (add-hook 'elfeed-fetch-functions #'nam/elfeed-calibre-fetch-issues)
    (nam/elfeed-calibre-import-issues)))

(provide 'personal-elfeed-calibre-issues)
;;; elfeed-calibre-issues.el ends here
