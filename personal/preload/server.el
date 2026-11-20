;;; -*- lexical-binding: nil; -*-
;;; server.el --- Emacs server + Zathura inverse search

(require 'server)

(unless (or noninteractive (server-running-p))
  (condition-case err
      (server-start)
    (file-error
     (message "Skipping Emacs server startup: %s" (error-message-string err)))))

(defun my/zathura-inverse-search (file line)
  "Jump to FILE at LINE from Zathura inverse search, then recenter."
  (let* ((line-num (if (numberp line)
                       line
                     (string-to-number line)))
         (buffer (find-file-noselect file)))
    (pop-to-buffer buffer)
    (goto-char (point-min))
    (forward-line (1- line-num))
    ;; Same idea as pressing C-l: center current line.
    (recenter)

    ;; Try to focus/raise Emacs after jumping.
    (when (display-graphic-p)
      (raise-frame)
      (select-frame-set-input-focus (selected-frame)))))
