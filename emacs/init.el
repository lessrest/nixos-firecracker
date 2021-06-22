(column-number-mode)
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1)
  (menu-bar-mode -1)
  (scroll-bar-mode -1))

(setq tab-always-indent 'complete)

(progn
  (setq gc-cons-threshold 20000)
  (setq kill-ring-max 1000)
  (setq enable-recursive-minibuffers t)

  (add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

  (progn
    (setq backup-by-copying t
          backup-directory-alist '(("." . "~/.saves/"))
          delete-old-versions t
          kept-new-versions 6
          kept-old-versions 2
          version-control t)
    (setq auto-save-file-name-transforms `((".*" ,temporary-file-directory t)))
    (setq backup-directory-alist `((".*" . ,temporary-file-directory))))

  (setq fill-nobreak-predicate '(fill-single-word-nobreak-p))
  (setq kill-whole-line t)
  (setq whitespace-style '(face trailing lines-tail empty))
  (setq uniquify-buffer-name-style 'post-forward-angle-brackets)

  (eval-after-load 'tramp
    '(add-to-list 'tramp-remote-path "/run/current-system/sw/bin"))

  (progn
    (put 'downcase-region 'disabled nil)
    (put 'upcase-region 'disabled nil)))

;; Configure indentation.
(progn
  (setq-default indent-tabs-mode nil)
  (electric-indent-mode -1)

  (setq c-basic-offset 2)
  (setq css-indent-offset 2)
  (setq js-indent-level 2)
  (setq sh-basic-offset 2))

;; Builtin global modes.
(progn
  (global-auto-revert-mode))

(defmacro save-column (&rest body)
  `(let ((column (current-column)))
     (unwind-protect
         (progn ,@body)
       (move-to-column column))))
(put 'save-column 'lisp-indent-function 0)

(defun move-line-up ()
  (interactive)
  (save-column
    (transpose-lines 1)
    (forward-line -2)))

(defun move-line-down ()
  (interactive)
  (save-column
    (forward-line 1)
    (transpose-lines 1)
    (forward-line -1)))

(defun sort-lines-dwim ()
  "Sort the lines in the buffer (or the region, if active)."
  (interactive)
  (if (region-active-p)
      (call-interactively 'sort-lines)
    (sort-lines nil (point-min) (point-max))))

;; Unset prefixes
(progn
  (global-unset-key (kbd "C-c c"))
  (global-unset-key (kbd "C-M-o"))
  (global-unset-key (kbd "C-M-h")))

(progn
  (global-set-key (kbd "C-c f") 'projectile-find-file)
  (global-set-key (kbd "C-c s") 'magit-status)
  (global-set-key (kbd "C-c g") 'deadgrep)
  (global-set-key (kbd "M-n") 'move-line-down)
  (global-set-key (kbd "M-p") 'move-line-up))

(progn
  (global-set-key (kbd "C-M-h f") 'describe-function)
  (global-set-key (kbd "C-M-h v") 'describe-variable)
  (global-set-key (kbd "C-M-h k") 'describe-key)
  (global-set-key (kbd "C-M-x") 'eval-defun)
  (global-set-key (kbd "C-c a") 'align-regexp)
  (global-set-key (kbd "C-c a") 'align-regexp)
  (global-set-key (kbd "C-c b") 'shell)
  (global-set-key (kbd "C-c d c") 'describe-char)
  (global-set-key (kbd "C-c d f") 'describe-function)
  (global-set-key (kbd "C-c d m") 'describe-mode)
  (global-set-key (kbd "C-c f") 'projectile-find-file)
  (global-set-key (kbd "C-c g") 'projectile-ag)
  (global-set-key (kbd "C-c j") 'join-line)
  (global-set-key (kbd "C-c k") 'fundamental-mode)
  (global-set-key (kbd "C-c m") 'make-directory)
  (global-set-key (kbd "C-c n") 'normal-mode)
  (global-set-key (kbd "C-c o") 'occur)
  (global-set-key (kbd "C-c w") 'browse-url)
  (global-set-key (kbd "C-c y") 'browse-kill-ring)
  (global-set-key (kbd "C-c z") 'sort-lines-dwim)
  (global-set-key (kbd "C-h") 'backward-delete-char)
  (global-set-key (kbd "C-x C-b") 'ibuffer)
  (global-set-key (kbd "C-x C-o") 'other-window)
  (global-set-key (kbd "C-x t") 'string-rectangle)
  (global-set-key (kbd "M-/") 'hippie-expand)
  (global-set-key (kbd "M-h") 'backward-kill-word)
  (global-set-key (kbd "RET") 'newline)
  )

(progn
  (add-hook 'emacs-lisp-mode-hook 'enable-paredit-mode)
  (add-hook 'clojure-mode-hook 'enable-paredit-mode)
  (add-hook 'lisp-mode-hook 'enable-paredit-mode))

(progn
  (require 'dired)
  (require 'dired-x)
  (define-key dired-mode-map (kbd "r") 'wdired-change-to-wdired-mode)
  )

(global-whitespace-cleanup-mode)

(setq magit-completing-read-function 'magit-ido-completing-read)
(setq magit-last-seen-setup-instructions "1.4.0")
(setq magit-stage-all-confirm nil)
(setq magit-status-buffer-switch-function 'switch-to-buffer)
(setq magit-unstage-all-confirm nil)

(add-hook 'cider-mode-hook #'eldoc-mode)
(add-hook 'cider-repl-mode-hook #'eldoc-mode)

(eval-after-load 'clojure-mode
  '(progn
     (define-clojure-indent (match 1))
     (define-clojure-indent (filter 1))
     (define-clojure-indent (sort-by 1))
     (define-clojure-indent
       (defroutes 'defun)
       (GET 2)
       (POST 2)
       (PUT 2)
       (DELETE 2)
       (HEAD 2)
       (ANY 2)
       (OPTIONS 2)
       (PATCH 2)
       (rfn 2)
       (let-routes 1)
       (context 2))
     )
  )

(eval-after-load 'cider-mode
  '(define-key cider-mode-map (kbd "C-c C-p") 'cider-test-run-project-tests)
  )

(defun restless-rebuild ()
  (interactive)
  (compile "sudo time make -C /restless"))

(global-set-key (kbd "C-c R") #'restless-rebuild)

(selectrum-mode 1)
(selectrum-prescient-mode 1)
(prescient-persist-mode 1)

(load-theme 'deeper-blue t)

(add-hook 'elixir-mode-hook 'lsp)
