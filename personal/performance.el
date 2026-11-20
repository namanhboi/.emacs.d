;;; performance.el --- Keep background updates out of editing -*- lexical-binding: t; -*-

;; Recursive status scans from diff-hl-dired caused a measured stall in
;; large repositories.
(with-eval-after-load 'diff-hl
  (setq diff-hl-update-async t)
  (global-diff-hl-mode -1)
  (remove-hook 'dired-mode-hook #'diff-hl-dired-mode)
  (remove-hook 'dired-mode-hook #'diff-hl-dired-mode-unless-remote)
  (add-hook 'prog-mode-hook #'turn-on-diff-hl-mode)
  (add-hook 'vc-dir-mode-hook #'turn-on-diff-hl-mode)
  ;; Also update buffers that are already open when this file is evaluated.
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (bound-and-true-p diff-hl-dired-mode)
        (when (and (boundp 'diff-hl-dired-process-buffer)
                   (buffer-live-p diff-hl-dired-process-buffer))
          (let ((process (get-buffer-process diff-hl-dired-process-buffer)))
            (when process
              (set-process-sentinel process #'ignore)
              (when (process-live-p process) (delete-process process)))))
        (diff-hl-dired-mode -1))
      (when (derived-mode-p 'prog-mode 'vc-dir-mode)
        (turn-on-diff-hl-mode)))))

(with-eval-after-load 'eglot
  (setq eglot-sync-connect nil))

;; Preview Consult candidates immediately when moving through results.
(defvar consult-preview-key)
(with-eval-after-load 'consult
  (setq consult-preview-key 'any))

(with-eval-after-load 'smartparens
  ;; Smartparens leaves this timer running after its highlighting is disabled.
  ;; Its mode command creates a fresh timer if highlighting is enabled later.
  (unless (seq-some (lambda (buffer)
                      (buffer-local-value 'show-smartparens-mode buffer))
                    (buffer-list))
    (when (timerp sp-show-pair-idle-timer)
      (cancel-timer sp-show-pair-idle-timer)
      (setq sp-show-pair-idle-timer nil))))

;; The 128 MiB trial produced longer individual GC pauses.  The controlled
;; completion replay favored the original 50 MB threshold over 16/32 MiB
;; (more collections) and 128 MiB (longer pauses).
(with-eval-after-load 'gcmh
  ;; GCMH 0.2.1 uses an ordinary timer and does not cancel it on disable.
  (when (timerp gcmh-idle-timer) (cancel-timer gcmh-idle-timer))
  (when gcmh-mode (gcmh-mode -1)))
(setq gc-cons-threshold 50000000
      gc-cons-percentage 0.1)

(defvar nam/gc-idle-timer nil
  "Timer for collecting garbage after two seconds without user input.")

(defun nam/idle-garbage-collect ()
  "Collect garbage during a genuine idle period when no input is queued."
  (unless (input-pending-p)
    (garbage-collect)))

(when (timerp nam/gc-idle-timer) (cancel-timer nam/gc-idle-timer))
(setq nam/gc-idle-timer
      (run-with-idle-timer 2 t #'nam/idle-garbage-collect))
