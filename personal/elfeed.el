;;; elfeed.el --- Personal RSS subscriptions -*- lexical-binding: t; -*-

;;; Commentary:
;; Open with M-x elfeed, then press G to fetch updates.
;; Filter with s +youtube or s +news; RET opens a local Calibre news issue.
;; YouTube subscriptions use the videos-only playlists to exclude Shorts.
;; Press v to play selected videos in a normal mpv window (f toggles fullscreen,
;; q quits).  C-u v chooses 720p or 1080p for that playlist.
;; English subtitles are requested, with automatic captions as a fallback.

;;; Code:

(defcustom nam/elfeed-mpv-max-height 1080
  "Default maximum video height for Elfeed playback in mpv.
Use C-u v to choose a different quality for a single playlist."
  :type '(choice (const :tag "720p" 720)
                 (const :tag "1080p" 1080))
  :group 'elfeed)

(defun nam/elfeed-play-in-mpv (&optional choose-quality)
  "Play selected Elfeed entries as a playlist in a normal mpv window.
With prefix argument CHOOSE-QUALITY, prompt for 720p or 1080p.
Do not launch another player while the same playlist is already open."
  (interactive "P")
  (unless (executable-find "mpv")
    (user-error "mpv is not installed or is missing from Emacs's exec-path"))
  (let* ((entries (cond
                   ((derived-mode-p 'elfeed-search-mode)
                    (elfeed-search-selected))
                   ((derived-mode-p 'elfeed-show-mode)
                    (list elfeed-show-entry))
                   (t (user-error "Run this command in Elfeed"))))
         (urls (delete-dups
                (delq nil (mapcar #'elfeed-entry-link (delq nil entries))))))
    (unless urls
      (user-error "No Elfeed entries selected"))
    (if-let* ((existing
               (seq-find
                (lambda (process)
                  (and (process-live-p process)
                       (string-prefix-p "elfeed-mpv" (process-name process))
                       (equal urls (cdr (member "--" (process-command process))))))
                (process-list))))
        (progn
          (message "Already open in mpv; quit that player with q before replaying or changing quality")
          existing)
      (let ((height (if choose-quality
			(string-to-number
			 (completing-read "Video quality for this playlist: "
                                          '("720p" "1080p") nil t nil nil
                                          (format "%dp" nam/elfeed-mpv-max-height)))
                      nam/elfeed-mpv-max-height)))
	(make-process :name "elfeed-mpv"
                      :buffer "*elfeed-mpv*"
                      :command (append '("mpv" "--no-fullscreen"
					 "--no-window-maximized" "--border=yes"
					 "--autofit-larger=1280x720"
					 "--cache=yes" "--cache-secs=120"
					 "--demuxer-max-bytes=128MiB"
					 "--cache-pause-initial=yes"
					 "--cache-pause-wait=3"
					 "--slang=en,en-US,en-GB,en-orig,eng"
					 "--sub-visibility=yes"
					 ;; mpv 0.34's hook recognizes the singular
					 ;; sub-lang key and avoids requesting all
					 ;; subtitle languages.
					 "--ytdl-raw-options=write-subs=,write-auto-subs=,sub-lang=en.*,sub-format=vtt")
                                       (list (format "--ytdl-format=bestvideo[height<=%d]+bestaudio/best[height<=%d]"
                                                     height height)
                                             "--")
                                       urls)
                      :noquery t)))))

(use-package elfeed
  :ensure t
  :commands (elfeed elfeed-update)
  :init
  (setq elfeed-db-directory (expand-file-name "elfeed" user-emacs-directory)
        elfeed-search-filter "+unread")
  :config
  (define-key elfeed-search-mode-map (kbd "v") #'nam/elfeed-play-in-mpv)
  (define-key elfeed-show-mode-map (kbd "v") #'nam/elfeed-play-in-mpv)
  ;; Remove former article feeds and mixed YouTube feeds when reloading.
  (setq elfeed-feeds
        (seq-remove (lambda (feed)
                      (let ((url (if (stringp feed) feed (car feed))))
                        (or (member url '("https://www.theatlantic.com/feed/all/"
                                          "https://www.ft.com/rss/home/uk"))
                            (string-match-p
                             "\\`https?://\\(?:www\\.\\)?economist\\.com/" url)
                            (string-prefix-p
                             "https://www.youtube.com/feeds/videos.xml?channel_id=" url))))
                    elfeed-feeds))
  ;; Keep any existing subscriptions when this file is reloaded.
  (dolist (feed
           '(;; fern (@fern-tv)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFODHrzPMGbNv67e84WDZhQQ" :title "fern" youtube fern)
             ;; Alfie Potts Harmer (@alfiepottsharmer1899)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULF2HaP70SXBXtpMjxqV_fFgQ" :title "Alfie Potts Harmer" youtube alfie-potts-harmer)
             ;; Veritasium (@veritasium)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFHnyfMqiRRG1u-2MsSQLbXA" :title "Veritasium" youtube veritasium)
             ;; BobbyBroccoli (@BobbyBroccoli)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFSPLhwvj0gBufjDRzSQb3GQ" :title "BobbyBroccoli" youtube bobbybroccoli)
             ;; NakeyJakey (@NakeyJakey)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFSdma21fnJzgmPodhC9SJ3g" :title "NakeyJakey" youtube nakeyjakey)
             ;; Fredrik Knudsen (@FredrikKnudsen)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFbWcXB0PoqOsAvAdfzWMf0w" :title "Fredrik Knudsen" youtube fredrik-knudsen)
             ;; Polyblank (@AgentPolyblank)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULF3Wjd7TzfReIIW5EskBLnqA" :title "Polyblank" youtube polyblank)
             ;; Rantoni (@RealRantoni)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFREHHX2Lk_BYGS9R0ia7DDQ" :title "Rantoni" youtube rantoni)
             ;; Adrian Clarke (@AdrianClarke-29)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULF9SRbYyxmrS1pjgQnFSE_BQ" :title "Adrian Clarke" youtube adrian-clarke)
             ;; The Adam Clery Football Channel (@ACFC)
             ("https://www.youtube.com/feeds/videos.xml?playlist_id=UULFRXVJv9f3oob6l3-ktUbXUA" :title "The Adam Clery Football Channel" youtube acfc)))
    (add-to-list 'elfeed-feeds feed t)))

(provide 'personal-elfeed)
;;; elfeed.el ends here
