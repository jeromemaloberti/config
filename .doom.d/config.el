;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Jerome Maloberti"
      user-mail-address "jmaloberti@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font (font-spec :family "Fira Code" :size 16))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'spacemacs-dark)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c g k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c g d') to jump to their definition and see how
;; they are implemented.

(global-unset-key (kbd "C-z"))
(global-unset-key (kbd "C-b"))
;(map!
; (:desc "Tabs" :prefix "\C-b"
;   :desc "Next tab" "n" 'centaur-tabs-forward
;   :desc "Previous tab" "p" 'centaur-tabs-backward))

(use-package! elscreen
  :config
  (custom-set-variables '(elscreen-tab-display-control nil) ; hide control tab at the left side
                        '(elscreen-tab-display-kill-screen nil) ; hide kill button
                        '(elscreen-display-tab t))
  (custom-set-faces '(elscreen-tab-current-screen-face ((t (:inherit default :weight bold)))))
  :init (progn
          (setq elscreen-prefix-key "\C-b")
          (load "elscreen" "ElScreen" t)
          (elscreen-start)))

(use-package! multi-term
  :commands (multi-term multi-term-dedicated-open)
  :init (progn
	  (setq term-unbind-key-list '("C-z" "C-x" "C-c" "C-h" "C-y" "<ESC>" "C-b"))
	  (setq multi-term-program "/bin/bash")))

(use-package! org-sidebar ;; keys ?
  :custom (org-sidebar-tree-side 'left))

(use-package! org-superstar
  :config
  (setq org-superstar-remove-leading-stars t
        org-superstar-prettify-item-bullets t
        org-superstar-special-todo-items t))

(setq projectile-enable-caching t)
(setenv "WORKON_HOME" "/Users/jeromem/anaconda3/envs")
(setq! tramp-ssh-controlmaster-options "-o ControlMaster=auto -o ControlPath='tramp.%%C' -o ControlPersist=10")
(setq! vc-ignore-dir-regexp (format "\\(%s\\)\\|\\(%s\\)" vc-ignore-dir-regexp tramp-file-name-regexp)
       tramp-copy-size-limit nil
       tramp-default-method "scpx"
       tramp-completion-reread-directory-timeout t)
(defun tramp-abort ()
  (interactive)
  (recentf-cleanup)
  (tramp-cleanup-all-buffers)
  (tramp-cleanup-all-connections))

(fast-scroll-config)
(fast-scroll-mode 1)
(add-to-list 'default-frame-alist '(inhibit-double-buffering . t))
(after! ace-window
  (setq aw-keys '(?a ?o ?e ?u ?i ?d ?h ?t ?n ?s)))
