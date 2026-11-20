;;; java-eglot.el --- Java language server setup -*- lexical-binding: t; -*-

;;; Commentary:

;; JDT needs Lombok loaded into its own JVM to understand generated accessors
;; and constructors.  Keep its workspace separate for each full project path.

;;; Code:

(require 'eglot)
(require 'subr-x)

(defcustom nam/java-jdtls-program nil
  "JDT launcher, or nil to prefer the compatible local runtime.
Install that runtime with utils/install-jdtls.sh.  Fall back to jdtls on PATH."
  :type '(choice (const :tag "Find automatically" nil) file)
  :group 'java)

(defun nam/java-jdtls-program ()
  "Return the configured or available local JDT launcher."
  (or nam/java-jdtls-program
      (let ((bundled (expand-file-name
                      (locate-user-emacs-file
                       "savefile/jdtls-runtime/1.55.0/bin/jdtls"))))
        (when (file-executable-p bundled) bundled))
      (executable-find "jdtls")))

(defcustom nam/java-lombok-jar nil
  "Lombok agent jar for JDT, or nil to find one in local dependency caches."
  :type '(choice (const :tag "Find automatically" nil) file)
  :group 'java)

(defun nam/java-find-lombok ()
  "Find a runnable Lombok jar, excluding source and JavaDoc jars."
  (or nam/java-lombok-jar
      (car
       (sort
        (seq-filter
         (lambda (path)
           (string-match-p "/lombok-[0-9.]+\\.jar\\'" path))
         (append
          (file-expand-wildcards
           (expand-file-name
            "~/.gradle/caches/modules-2/files-2.1/org.projectlombok/lombok/*/*/*.jar"))
          (file-expand-wildcards
           (expand-file-name "~/.m2/repository/org/projectlombok/lombok/*/*.jar"))))
        (lambda (a b)
          (version< (string-remove-prefix "lombok-" (file-name-base b))
                    (string-remove-prefix "lombok-" (file-name-base a))))))))

(defun nam/java-eglot-contact (&optional _interactive)
  "Start JDT with a project-specific workspace and local Lombok support."
  (if (file-remote-p default-directory)
      '("jdtls")
    (let* ((program (or (nam/java-jdtls-program)
                        (user-error "Install jdtls first")))
           (project (project-current nil))
           (root (file-truename
                  (if project (project-root project) default-directory)))
           (workspace (expand-file-name
                       (secure-hash 'sha1 (concat root "\0" program))
                       (locate-user-emacs-file "savefile/jdtls/")))
           (lombok (nam/java-find-lombok)))
      (make-directory workspace t)
      (append (list program)
              (when (and lombok (file-readable-p lombok))
                (list (concat "--jvm-arg=-javaagent:" lombok)))
              (list "-data" workspace)))))

(add-to-list 'eglot-server-programs
             '((java-mode java-ts-mode) . nam/java-eglot-contact))

(defun nam/java-eglot-enable ()
  "Enable Java's language server when jdtls is available."
  (when (if (file-remote-p default-directory)
            (executable-find "jdtls" t)
          (nam/java-jdtls-program))
    ;; Use the envrc-aware Prelude entry point so Java does not race direnv.
    (prelude-lsp-enable)))

(add-hook 'java-mode-hook #'nam/java-eglot-enable)
(add-hook 'java-ts-mode-hook #'nam/java-eglot-enable)

(provide 'nam-java-eglot)
;;; java-eglot.el ends here
