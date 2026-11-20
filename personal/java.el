;;; java.el --- DSLabs Java formatting defaults -*- lexical-binding: t; -*-

;;; Commentary:

;; Follow the unmodified DSLabs Google Java Format configuration for every
;; Java source buffer, including tests, package-info.java and module-info.java.
;; The formatter also handles import ordering, wrapping and JavaDoc layout.

;;; Code:

(require 'cc-mode)
(require 'subr-x)

(defcustom nam/java-format-jar
  (expand-file-name "~/dslabs/jars/google-java-format.jar")
  "Google Java Format jar used for all Java buffers.
When unavailable, use the google-java-format executable from PATH."
  :type 'file
  :group 'java)

(c-add-style
 "nam/google-java"
 '("java"
   (c-basic-offset . 2)
   (c-offsets-alist
    (substatement-open . 0)
    (statement-cont . ++)
    (arglist-intro . ++)
    (arglist-cont-nonempty . ++)
    (arglist-close . 0)
    (inher-cont . ++)
    (func-decl-cont . ++))))

(defun nam/java-format-buffer ()
  "Format the whole Java buffer with DSLabs' Google Java Format defaults.
Run locally even when editing through TRAMP.  Only replace the buffer after
successful formatting, preserving point and keeping the change undoable."
  (interactive)
  (unless (derived-mode-p 'java-mode 'java-ts-mode)
    (user-error "This command requires a Java buffer"))
  (let* ((default-directory temporary-file-directory)
         (command
          (cond
           ((and (file-readable-p nam/java-format-jar)
                 (executable-find "java"))
            (list (executable-find "java") "-jar" nam/java-format-jar))
           ((executable-find "google-java-format")
            (list (executable-find "google-java-format")))
           (t (user-error
               "Install google-java-format or set nam/java-format-jar"))))
         (output (generate-new-buffer " *google-java-format*"))
         (coding-system-for-read 'utf-8-unix)
         (coding-system-for-write 'utf-8-unix))
    (unwind-protect
        (save-restriction
          (widen)
          (let ((status (apply #'call-process-region
                               (point-min) (point-max) (car command)
                               nil (list output t) nil
                               (append (cdr command) '("-")))))
            (unless (eql status 0)
              (user-error "Google Java Format failed: %s"
                          (with-current-buffer output
                            (string-trim (buffer-string)))))
            (atomic-change-group
              (replace-buffer-contents output))))
      (kill-buffer output))))

(defun nam/java-style-setup ()
  "Use DSLabs' Google Java style in the current Java buffer."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100
              whitespace-line-column 100)
  (if (derived-mode-p 'java-ts-mode)
      (progn
        (setq-local java-ts-mode-indent-offset 2)
        ;; Tree-sitter otherwise uses the block width for continuations too.
        (setq-local
         treesit-simple-indent-rules
         `((java
            ((parent-is
              ,(concat
                "\\`"
                (regexp-opt '("argument_list" "annotation_argument_list"
                              "formal_parameters" "local_variable_declaration"
                              "expression_statement" "field_declaration"
                              "return_statement" "variable_declarator"
                              "type_arguments" "method_invocation"
                              "ternary_expression" "assignment_expression"
                              "binary_expression"))
                "\\'"))
             parent-bol 4)
            ,@(cdr (assq 'java treesit-simple-indent-rules))))))
    (c-set-style "nam/google-java"))
  (local-set-key (kbd "C-c C-l f") #'nam/java-format-buffer)
  (local-set-key [remap eglot-format-buffer] #'nam/java-format-buffer)
  ;; Formatting is explicit; also remove the old hook when reloading settings.
  (remove-hook 'before-save-hook 'nam/java-format-on-save t))

(add-hook 'java-mode-hook #'nam/java-style-setup)
(add-hook 'java-ts-mode-hook #'nam/java-style-setup)

(provide 'nam-java)
;;; java.el ends here
