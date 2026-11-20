;;; -*- lexical-binding: nil; -*-
;; Compatibility for newer Marginalia on Emacs builds where
;; `seconds-to-string' only accepts one argument.
(require 'time-date)

(when (equal (func-arity #'seconds-to-string) '(1 . 1))
  (defalias 'nam/seconds-to-string-1arg
    (symbol-function 'seconds-to-string))

  (defun seconds-to-string (seconds &optional _format _short)
    (funcall #'nam/seconds-to-string-1arg seconds)))

(setq prelude-undo-tree nil
      prelude-flyspell nil
      prelude-projectile nil)

;; Linux sleep inhibition needs an Emacs build with D-Bus support.
(when (and (eq system-type 'gnu/linux)
           (not (featurep 'dbusbind)))
  (setq agent-shell-inhibit-system-sleep nil))
