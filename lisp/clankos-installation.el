;;; clankos-installation.el --- Plan one repository's installation -*- lexical-binding: t; -*-

;;; Commentary:
;; Read configuration with poslib and keep discovery inside one repository.
;; The plan describes nodes and saved intent.  It performs no installation.

;;; Code:
(require 'cl-lib)
(require 'json)
(require 'pos-node)
(require 'pos-lock)
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

(provide 'clankos-installation)
;;; clankos-installation.el ends here
