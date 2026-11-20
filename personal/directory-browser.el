;;; directory-browser.el --- Dired with file icons -*- lexical-binding: t; -*-

(prelude-require-package 'nerd-icons-dired)

(use-package nerd-icons-dired
  :ensure nil
  :hook (dired-mode . nerd-icons-dired-mode))
