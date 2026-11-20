;;; -*- lexical-binding: nil; -*-
(require 'grep)

(when (executable-find "rg")
  (grep-apply-setting
   'grep-find-command
   '("rg -n -H --no-heading -e '' $(git rev-parse --show-toplevel || pwd)" . 27)))

(unless (executable-find "rg")
  (if (executable-find "grep")
      (global-set-key (kbd "M-s r") #'consult-grep)
    (global-unset-key (kbd "M-s r"))))

(global-set-key (kbd "C-x r g") #'grep-find)
