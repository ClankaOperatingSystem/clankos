;;; clankos-installation.el --- Plan and edit one repository's installation -*- lexical-binding: t; -*-

;;; Commentary:
;; Read configuration with poslib and keep discovery inside one repository.
;; Save edit intent before configuration.  These commands perform no installation.

;;; Code:
(require 'cl-lib)
(require 'json)
(require 'pos-node)
(require 'pos-lock)
(require 'pos-sources)
(require 'pos-bytes)

(defun clankos-installation--read (file)
  "Read FILE as text without visiting it."
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defun clankos-installation--path (path)
  "Refuse a PATH that is not a normal relative node path."
  (unless (and (stringp path)
               (or (equal path ".")
                   (and (not (file-name-absolute-p path))
                        (not (string-empty-p path))
                        (not (seq-intersection (split-string path "/")
                                               '("" "." "..") #'equal)))))
    (error "Invalid node path: %S" path))
  path)

(defun clankos-installation--boundary (root path)
  "Check PATH below ROOT, returning non-nil at a nested repository.
Refuse symbolic links before reading their targets."
  (clankos-installation--path path)
  (let ((dir root) boundary)
    (unless (equal path ".")
      (catch 'stop
        (dolist (part (split-string path "/"))
          (setq dir (expand-file-name part dir))
          (when (file-symlink-p dir) (error "Symbolic link in node path: %s" path))
          (when (or (file-exists-p (expand-file-name ".git" dir))
                    (file-symlink-p (expand-file-name ".git" dir)))
            (setq boundary t)
            (throw 'stop t)))))
    boundary))

(defun clankos-installation--config (dir)
  "Find a configuration in DIR without following configuration symlinks."
  (dolist (name '(".clanka" ".clankos" ".pos"))
    (let ((path (expand-file-name name dir)))
      (when (file-symlink-p path) (error "Symbolic configuration directory: %s" path))
      (dolist (file '("config.yaml" "config.yml"))
        (when (file-symlink-p (expand-file-name file path))
          (error "Symbolic configuration file: %s/%s" path file)))))
  (when-let* ((file (pos-node-config-file dir)))
    (expand-file-name file dir)))

(defun clankos-installation--state (file)
  "Read and validate the managed identities in FILE, or return an empty vector."
  (when (file-symlink-p file) (error "Symbolic installation state: %s" file))
  (if (not (file-exists-p file)) []
    (let* ((data (json-parse-string (clankos-installation--read file)
                                    :object-type 'alist :array-type 'array
                                    :null-object :null :false-object :false))
           (managed (alist-get 'managed data))
           seen)
      (unless (and (= (length data) 2) (equal (alist-get 'schema data) 1)
                   (vectorp managed))
        (error "Installation state needs schema 1 and a managed array"))
      (seq-doseq (entry managed)
        (unless (and (listp entry) (= (length entry) 4)
                     (assq 'node entry) (assq 'source entry)
                     (assq 'skill entry) (assq 'disposition entry))
          (error "Invalid managed identity: %S" entry))
        (let ((node (clankos-installation--path (alist-get 'node entry)))
              (source (alist-get 'source entry))
              (skill (alist-get 'skill entry))
              (disposition (alist-get 'disposition entry)))
          (unless (and (stringp source) (not (string-empty-p source))
                       (stringp skill) (string-match-p pos-node-skill-name-regexp skill)
                       (member disposition '(:null "keep" "remove")))
            (error "Invalid managed identity: %S" entry))
          (let ((identity (list node (pos-node-source-key source) skill)))
            (when (member identity seen) (error "Duplicate managed identity: %S" identity))
            (push identity seen))))
      managed)))

(defun clankos-installation-plan (root)
  "Return the installation plan for ROOT, a repository's root directory.
Read only local configured nodes and previously managed identities."
  (setq root (file-name-as-directory (file-truename root)))
  (let* ((default-directory root)
         (git-root (with-temp-buffer
                     (unless (eq 0 (call-process "git" nil t nil "rev-parse" "--show-toplevel"))
                       (error "Not a Git repository"))
                     (file-name-as-directory (file-truename (string-trim (buffer-string))))))
         (file (clankos-installation--config root)))
    (unless (equal root git-root) (error "Run installation-plan at the repository root"))
    (unless file (error "No configuration at the repository root"))
    (let ((managed (clankos-installation--state
                    (expand-file-name "installation-state.json" (file-name-directory file))))
          (visited (make-hash-table :test #'equal)) nodes skipped)
      (cl-labels
          ((visit
            (path)
            (unless (gethash path visited)
              (puthash path t visited)
              (if (clankos-installation--boundary root path)
                  (push path skipped)
                (let* ((dir (expand-file-name path root))
                       (config-file (clankos-installation--config dir)))
                  (when config-file
                    (let* ((config (pos-node-read-config (clankos-installation--read config-file)))
                           (sources (alist-get 'methodologies config))
                           (projects (alist-get 'projects config)))
                      (push `((path . ,path) (status . "configured")
                              (config . ,(file-relative-name config-file root))
                              (sources . ,(if (vectorp sources) sources []))
                              (legacy . ,(if (stringp sources) sources :null))
                              (image . ,(if (equal path ".")
                                            (or (pos-lock-image "/usr/local/share/clankos/source" root) :null)
                                          :null))) nodes)
                      (seq-doseq (child (alist-get 'children config))
                        (let ((relative (file-relative-name
                                         (expand-file-name (alist-get 'path child) dir) root)))
                          (if (not (eq (alist-get 'remote child) :null))
                              (push relative skipped)
                            (visit relative))))
                      (when (stringp projects)
                        (let ((relative (directory-file-name
                                         (file-relative-name (expand-file-name projects dir) root))))
                          (if (clankos-installation--boundary root relative)
                              (push relative skipped)
                            (let ((parent (expand-file-name relative root)))
                              (when (file-directory-p parent)
                                (dolist (entry (directory-files parent nil directory-files-no-dot-files-regexp))
                                  (unless (string-match-p "\\`[._]" entry)
                                    (let ((child (concat relative "/" entry)))
                                      (clankos-installation--boundary root child)
                                      (when (file-directory-p (expand-file-name child root))
                                        (visit child)))))))))))))))))
        (visit "."))
      (seq-doseq (entry managed)
        (let* ((path (alist-get 'node entry))
               (node (seq-find (lambda (n) (equal (alist-get 'path n) path)) nodes)))
          (unless node
            (let ((status (cond ((clankos-installation--boundary root path) "blocked")
                                ((not (file-exists-p (expand-file-name path root))) "missing")
                                ((not (file-directory-p (expand-file-name path root)))
                                 (error "Managed node is not a directory: %s" path))
                                (t "cleanup"))))
              (setq node `((path . ,path) (status . ,status) (config . :null)
                           (sources . []) (legacy . :null) (image . :null)))
              (push node nodes)))))
      (setq nodes
            (mapcar (lambda (node)
                      (cons (cons 'managed
                                  (vconcat (seq-filter
                                            (lambda (entry)
                                              (equal (alist-get 'node entry)
                                                     (alist-get 'path node)))
                                            managed)))
                            node))
                    nodes))
      `((schema . 1)
        (nodes . ,(vconcat (sort nodes (lambda (a b) (string< (alist-get 'path a) (alist-get 'path b))))))
        (skipped . ,(vconcat (sort (delete-dups skipped) #'string<)))))))

(defun clankos-installation-plan-batch ()
  "Print a plan as JSON, refusing invalid input without writing files."
  (condition-case err
      (pos-bytes-print (clankos-installation-plan default-directory))
    (error (message "installation-plan: %s" (error-message-string err)) (kill-emacs 1))))

(defun clankos-installation--write (file text)
  "Replace FILE with TEXT by renaming a temporary file beside it."
  (let ((temporary (make-temp-file (concat file "."))))
    (unwind-protect
        (progn
          (when (file-exists-p file)
            (set-file-modes temporary (file-modes file)))
          (with-temp-file temporary (insert text))
          (rename-file temporary file t))
      (when (file-exists-p temporary) (delete-file temporary)))))

(defun clankos-installation--identity (entry)
  "Return the identity of a managed ENTRY."
  (list (alist-get 'node entry)
        (pos-node-source-key (alist-get 'source entry))
        (alist-get 'skill entry)))

(defun clankos-installation-edit (root path action words &optional keep kind)
  "Edit the configured node PATH in ROOT using ACTION and WORDS.
KEEP retains removed skills; KIND selects an added source's kind.
Save ownership and removal intent before replacing the configuration."
  (let* ((plan (clankos-installation-plan root))
         (node (seq-find (lambda (each) (equal (alist-get 'path each) path))
                         (alist-get 'nodes plan))))
    (unless (and node (equal (alist-get 'status node) "configured"))
      (error "Not a configured node in this repository: %s" path))
    (let* ((file (expand-file-name (alist-get 'config node) root))
           (dir (expand-file-name path root))
           (state-file (expand-file-name
                        "installation-state.json"
                        (file-name-directory (clankos-installation--config root))))
           (managed (append (clankos-installation--state state-file) nil))
           (lock-file (expand-file-name pos-lock-file dir))
           (text (clankos-installation--read file))
           entries)
      (when (file-symlink-p lock-file) (error "Symbolic skills lock: %s" lock-file))
      (when (file-exists-p lock-file)
        (setq entries (pos-lock--entries lock-file))
        (when (or (eq entries :invalid)
                  (seq-some (lambda (pair)
                              (not (string-match-p pos-node-skill-name-regexp (car pair))))
                            entries))
          (error "Invalid skills lock: %s" lock-file)))
      (let* ((removed (and (equal action "remove")
                           (pos-sources-remove text dir (car words) (cdr words))))
             (new (pcase action
                    ("add" (pos-sources-add text (car words) (cadr words) (cddr words) kind))
                    ("remove" (alist-get 'text removed))
                    ("adopt" (pos-sources-adopt text dir words))
                    (_ (error "Unknown edit action: %s" action))))
             (sources (append (alist-get 'sources node) nil))
             (declared (alist-get 'methodologies (pos-node-read-config new)))
             (after (and (vectorp declared) (append declared nil))))
        (unless (eq (alist-get 'image node) :null)
          (push (alist-get 'image node) sources))
        ;; Seed only without history.  Later edits claim their explicit
        ;; targets; unrelated edits must not reclaim a released skill.
        (dolist (pair entries)
          (let* ((name (car pair))
                 (source (pos-sources--url (cdr pair)))
                 (before (and (or (not (file-exists-p state-file))
                                  (and (equal action "remove")
                                       (equal (pos-node-source-key (car words))
                                              (pos-node-source-key source))
                                       (or (not (cdr words)) (member name (cdr words)))))
                              (pos-sources--find sources source)))
                 (added (and (or (and (equal action "add")
                                      (equal (pos-node-source-key (car words))
                                             (pos-node-source-key source)))
                                 (and (equal action "adopt") (member name words)))
                             (pos-sources--find after source)))
                 (names (and added (alist-get 'skills added)))
                 (entry (list (cons 'node path)
                              (cons 'source (pos-node-source-key source))
                              (cons 'skill name) (cons 'disposition :null))))
            (when (and (or before
                           (and added (or (eq names :null) (seq-contains-p names name))))
                       (not (seq-find
                             (lambda (old)
                               (equal (clankos-installation--identity old)
                                      (clankos-installation--identity entry))) managed)))
              (push entry managed))))
        (when removed
          (dolist (entry managed)
            (when (and (equal path (alist-get 'node entry))
                       (equal (pos-node-source-key (car words))
                              (pos-node-source-key (alist-get 'source entry)))
                       (or (not (cdr words))
                           (member (alist-get 'skill entry) (cdr words))))
              (setf (alist-get 'disposition entry) (if keep "keep" "remove")))))
        ;; A failed configuration write leaves intent available for retry.
        ;; Apply must use the configuration on disk, never replay this edit.
        (let ((state (concat (json-serialize `((schema . 1) (managed . ,(vconcat managed)))
                                            :null-object :null) "\n")))
          (unless (and (file-exists-p state-file)
                       (equal state (clankos-installation--read state-file)))
            (clankos-installation--write state-file state)))
        (unless (equal text new) (clankos-installation--write file new))
        `((config . ,(alist-get 'config node)) (state . ,(file-relative-name state-file root)))))))

(defun clankos-installation-image (root image)
  "Set ROOT's runtime IMAGE without installing or changing Git's index."
  (unless (string-match-p "\\`[A-Za-z0-9./_-]+:v[0-9]+\\.[0-9]+\\.[0-9]+\\'" image)
    (error "Image needs a fixed release tag: %s" image))
  (clankos-installation-plan root)
  (let* ((file (clankos-installation--config root))
         (text (clankos-installation--read file))
         (line (concat "image: " image))
         (new (if (string-match "^image:.*$" text)
                  (replace-match line t t text)
                (concat text (unless (string-suffix-p "\n" text) "\n") line "\n"))))
    (pos-node-read-config new)
    (unless (equal text new) (clankos-installation--write file new))))

(defun clankos-installation-edit-batch ()
  "Edit configuration and saved intent without installing skills."
  (let* ((args command-line-args-left) (path (pop args)) (action (pop args))
         keep kind words)
    (setq command-line-args-left nil)
    (when (equal action "image")
      (unless (and (equal path ".") (= (length args) 1))
        (message "Usage: installation-edit . image IMAGE:vX.Y.Z")
        (kill-emacs 2))
      (condition-case err
          (progn (clankos-installation-image default-directory (car args)) (kill-emacs 0))
        (error (message "installation-edit: %s" (error-message-string err)) (kill-emacs 1))))
    (cl-flet ((usage ()
                (message "Usage: installation-edit NODE add SOURCE REF [SKILL ...] [--kind KIND]")
                (message "       installation-edit NODE remove SOURCE [SKILL ...] [--keep]")
                (message "       installation-edit NODE adopt SKILL ...")
                (kill-emacs 2)))
      (while args
        (let ((arg (pop args)))
          (cond ((and (equal arg "--keep") (equal action "remove") (not keep))
                 (setq keep t))
                ((and (equal arg "--kind") (equal action "add") args (not kind))
                 (setq kind (pop args)))
                ((string-prefix-p "-" arg) (usage))
                (t (push arg words)))))
      (setq words (nreverse words))
      (unless (and path (pcase action
                          ("add" (>= (length words) 2))
                          ((or "remove" "adopt") words)))
        (usage)))
    (condition-case err
        (pos-bytes-print (clankos-installation-edit default-directory path action words keep kind))
      (error (message "installation-edit: %s" (error-message-string err)) (kill-emacs 1)))))

(defun clankos-installation-apply-batch ()
  "Print the bounded input to the apply-v1 installer."
  (condition-case err
      (let* ((root default-directory)
             (plan (clankos-installation-plan root))
             (file (expand-file-name "installation-state.json"
                                     (file-name-directory (clankos-installation--config root))))
             (nodes
              (mapcar
               (lambda (node)
                 (when (equal (alist-get 'status node) "blocked")
                   (error "Managed node became a separate repository: %s" (alist-get 'path node)))
                 (unless (eq (alist-get 'legacy node) :null)
                   (error "Legacy path methodologies: replace the path with source declarations before apply-v1; see clankos-run help apply-v1"))
                 (let* ((file (alist-get 'config node))
                        (text (unless (eq file :null)
                                (clankos-installation--read (expand-file-name file root))))
                        (config (and text (pos-node-read-config text))))
                   (append (list (cons 'text (or text :null))
                                 (cons 'harnesses (or (alist-get 'harnesses config) :null))
                                 (cons 'bin (or (alist-get 'bin config) :null))) node)))
               (append (alist-get 'nodes plan) nil))))
        (pos-bytes-print
         `((schema . 1) (nodes . ,(vconcat nodes))
           (state . ,(file-relative-name file root))
           (before . ,(if (file-exists-p file) (clankos-installation--read file) :null)))))
    (error (message "apply-v1: %s" (error-message-string err)) (kill-emacs 1))))

(provide 'clankos-installation)
;;; clankos-installation.el ends here
