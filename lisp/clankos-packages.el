;;; clankos-packages.el --- The packages in the ClankOS image -*- lexical-binding: t; -*-

;;; Commentary:
;; Commands in the image run emacs -Q, which loads no packages.  They
;; load this file first.  It points Emacs at the packages the image was
;; built with: poslib, and what poslib requires from GNU and NonGNU
;; ELPA.  Nothing is read from or written to a home directory.

;;; Code:

(require 'package)

(defconst clankos-packages-directory "/usr/local/share/clankos/"
  "Where the image keeps poslib and the ELPA packages.")

(setq package-user-dir (expand-file-name "elpa" clankos-packages-directory)
      package-gnupghome-dir (expand-file-name "gnupg" package-user-dir)
      package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)
(add-to-list 'load-path (expand-file-name "poslib/lisp" clankos-packages-directory))

(provide 'clankos-packages)
;;; clankos-packages.el ends here
