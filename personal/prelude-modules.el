;;; prelude-modules.el --- Personal Prelude modules

;;; Commentary:

;; Load the default Prelude modules used by this configuration, plus Rust.

;;; Code:

;;; General productivity tools

(require 'prelude-vertico)
(require 'prelude-company)

;;; Org-mode

(require 'prelude-org)

;;; Programming languages support

(require 'prelude-c)
(require 'prelude-css)
(require 'prelude-emacs-lisp)
(require 'prelude-js)
(require 'prelude-lisp)
(require 'prelude-perl)
(require 'prelude-rust)
(require 'prelude-shell)
(require 'prelude-web)
(require 'prelude-xml)
(require 'prelude-yaml)

(provide 'prelude-modules)
;;; prelude-modules.el ends here
