;; Compatibility for newer Marginalia on Emacs builds where
;; `seconds-to-string' only accepts one argument.
(require 'time-date)

(when (equal (func-arity #'seconds-to-string) '(1 . 1))
  (defalias 'nam/seconds-to-string-1arg
    (symbol-function 'seconds-to-string))

  (defun seconds-to-string (seconds &optional _format _short)
    (funcall #'nam/seconds-to-string-1arg seconds)))

(setq prelude-undo-tree nil) ;; This prevents the "weirdness" from ever loading
