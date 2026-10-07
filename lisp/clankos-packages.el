;;; clankos-packages.el --- The packages in the ClankOS image -*- lexical-binding: t; -*-

;;; Commentary:
;; Commands in the image run emacs -Q, which loads no packages.  They
;; load this file first.  It points Emacs at the packages the image was
;; built with: poslib, and what poslib requires, markdown-mode, yaml,
;; and org-roam with compat, cond-let, llama, dash, emacsql,
;; magit-section and transient.  Nothing is read from or written to a
;; home directory.

;;; Code:

(defconst clankos-packages-directory "/usr/local/share/clankos/"
  "Where the image keeps poslib and the packages it requires.")

(dolist (directory '("markdown-mode" "yaml" "compat" "cond-let" "llama" "dash"
                     "emacsql" "transient/lisp" "magit-section" "org-roam"
                     "poslib/lisp"))
  (add-to-list 'load-path (expand-file-name directory clankos-packages-directory)))

(provide 'clankos-packages)
;;; clankos-packages.el ends here
