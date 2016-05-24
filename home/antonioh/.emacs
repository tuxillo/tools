;;;
;;; Temporary files go to temp diretory
;;;
(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))

;;;
;;; DragonFly BSD friendly C settings
;;;
(add-hook 'c-mode-common-hook 'bsd)

(defun bsd ()
  (interactive)
  (c-set-style "bsd")

  ;; Basic indent is 8 spaces
  (setq c-basic-offset 8)
  (setq tab-width 8)

  ;; Continuation lines are indented 4 spaces
  (c-set-offset 'arglist-cont 4)
  (c-set-offset 'arglist-cont-nonempty 4)
  (c-set-offset 'statement-cont 4)
  (c-set-offset 'cpp-macro-cont 8)

  ;; Labels are flush to the left
  (c-set-offset 'label [0])

  ;; Fill column
  (setq fill-column 74))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(inhibit-startup-screen t)
 '(require-final-newline t)
 '(show-trailing-whitespace t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
