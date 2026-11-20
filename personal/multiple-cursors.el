;;; multiple-cursors.el --- Multiple cursor editing -*- lexical-binding: t; -*-

(prelude-require-package 'multiple-cursors)

(use-package multiple-cursors
  :ensure nil
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

;;; multiple-cursors.el ends here
