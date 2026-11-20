;;; -*- lexical-binding: nil; -*-

;; Keep background package compiler diagnostics in the logs without popups.
(setq native-comp-async-report-warnings-errors 'silent)

(setq prelude-undo-tree nil
      prelude-flyspell nil
      prelude-projectile nil)

;; Linux sleep inhibition needs an Emacs build with D-Bus support.
(when (and (eq system-type 'gnu/linux)
           (not (featurep 'dbusbind)))
  (setq agent-shell-inhibit-system-sleep nil))
