;;; -*- lexical-binding: nil; -*-
(require 'grep)

(grep-apply-setting
 'grep-find-command
 '("rg -n -H --no-heading -e '' $(git rev-parse --show-toplevel || pwd)" . 27))

(global-set-key (kbd "C-x r g") #'grep-find)
