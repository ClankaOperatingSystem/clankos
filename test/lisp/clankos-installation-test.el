;;; clankos-installation-test.el --- Tests for clankos-installation.el  -*- lexical-binding: t -*-

;;; Commentary:

;; Run: make check.  The installation rules, on the host: each test
;; makes a repository in a temporary directory and an image's source
;; beside it, which `clankos-installation-source' is bound to.  The
;; image's repository is ClankOS's, at a commit of forty a's, with five
;; skills.

;;; Code:

(require 'ert)
(require 'clankos-installation)

(defconst clankos-installation-test-repository
  "https://github.com/ClankaOperatingSystem/clankos.git"
  "The repository the test image was built from.")

(defconst clankos-installation-test-commit (make-string 40 ?a)
  "The commit the test image was built from.")

(defconst clankos-installation-test-skills
  '("capture" "start-up" "wrap-up" "clankos-bootstrap" "clankos-lint")
  "The skills the test image holds.")

(defun clankos-installation-test--write (root files)
  "Write FILES under ROOT: (PATH . TEXT) pairs, directories made."
  (pcase-dolist (`(,path . ,text) files)
    (let ((file (expand-file-name path root)))
      (make-directory (file-name-directory file) t)
      (with-temp-file file (insert text)))))

(defun clankos-installation-test--git (root &rest args)
  "Run git with ARGS in ROOT, signalling if it fails."
  (let ((default-directory root))
    (unless (eq 0 (apply #'call-process "git" nil nil nil args))
      (error "Git %S failed" args))))

(defmacro clankos-installation-test-with-garden (files &rest body)
  "Evaluate BODY with `root' a new repository holding FILES.
FILES as for `clankos-installation-test--write'.  The image's source
is made beside it and `clankos-installation-source' bound to it."
  (declare (indent 1) (debug (form body)))
  `(let* ((dir (make-temp-file "clankos-installation-test-" t))
          (root (file-name-as-directory (expand-file-name "garden" dir)))
          (clankos-installation-source (expand-file-name "source" dir)))
     (unwind-protect
         (progn
           (make-directory root)
           (clankos-installation-test--git root "init" "-q" "-b" "master")
           (clankos-installation-test--write
            clankos-installation-source
            (append (list (cons "repository"
                                (concat clankos-installation-test-repository "\n"))
                          (cons "commit"
                                (concat clankos-installation-test-commit "\n")))
                    (mapcar (lambda (skill)
                              (cons (format "skills/%s/SKILL.md" skill) ""))
                            clankos-installation-test-skills)))
           (clankos-installation-test--write root ,files)
           ,@body)
       (delete-directory dir t))))

(defun clankos-installation-test--lock (&rest entries)
  "Return a skills-lock.json recording ENTRIES, each (NAME SOURCE)."
  (json-serialize
   `((version . 1)
     (skills . ,(mapcar (lambda (entry)
                          (cons (intern (car entry))
                                `((source . ,(cadr entry)) (ref . "v1")
                                  (sourceType . "github"))))
                        entries)))))

(defun clankos-installation-test--source (root url)
  "Return the entry of ROOT's configuration that declares URL, or nil."
  (let ((config (pos-node-read-config
                 (clankos-installation--read
                  (clankos-installation--config root)))))
    (clankos-installation--declared config url)))

(defun clankos-installation-test--skills (entry)
  "Return the skills ENTRY, a declared source, names, sorted."
  (sort (append (alist-get 'skills entry) nil) #'string<))

(defun clankos-installation-test--managed (root)
  "Return ROOT's managed identities, each (NODE SOURCE SKILL DISPOSITION)."
  (let ((state (json-parse-string
                (clankos-installation--read
                 (expand-file-name ".pos/installation-state.json" root))
                :object-type 'alist :null-object nil)))
    (mapcar (lambda (entry)
              (let-alist entry (list .node .source .skill .disposition)))
            (alist-get 'managed state))))

;;;; The plan

(ert-deftest clankos-installation/the-plan-reads-local-nodes-and-skips-mounts ()
  "The plan walks the root's children and projects that have a configuration.
A child with a remote is a repository of its own, skipped, and a
project with no configuration of its own is no node."
  (clankos-installation-test-with-garden
      '((".pos/config.yaml"
         . "projects: projects/\nchildren:\n  - path: home\n  - path: shared\n    remote: git@example.org:shared.git\n")
        ("home/.pos/config.yaml" . "projects: projects/\n")
        ("projects/roof/.pos/config.yaml" . "projects: projects/\n")
        ("projects/fence/notes.org" . "* TODO Paint the fence\n"))
    (let ((plan (clankos-installation-plan root)))
      (should (equal '("." "home" "projects/roof")
                     (mapcar (lambda (node) (alist-get 'path node))
                             (alist-get 'nodes plan))))
      (should (equal ["shared"] (alist-get 'skipped plan))))))

(ert-deftest clankos-installation/the-plan-is-made-at-the-repository-root ()
  "A plan asked for below the root, or of a root with no configuration, is refused."
  (clankos-installation-test-with-garden
      '(("home/notes.org" . "* Notes\n"))
    (should-error (clankos-installation-plan root))
    (clankos-installation-test--write root '((".pos/config.yaml" . "projects: projects/\n")))
    (should-error (clankos-installation-plan (expand-file-name "home" root)))))

;;;; Method zero

(ert-deftest clankos-installation/method-zero-declares-the-defaults-at-the-image-s-commit ()
  "With nothing installed from ClankOS, the defaults are declared at its commit."
  (clankos-installation-test-with-garden
      '((".pos/config.yaml" . "projects: projects/\n"))
    (clankos-installation-method-zero root)
    (let ((entry (clankos-installation-test--source
                  root clankos-installation-test-repository)))
      (should (equal clankos-installation-test-commit (alist-get 'ref entry)))
      (should (equal "skills-repository" (alist-get 'kind entry)))
      (should (equal (sort (copy-sequence clankos-installation-defaults) #'string<)
                     (clankos-installation-test--skills entry))))))

(ert-deftest clankos-installation/method-zero-leaves-out-a-slot-the-repository-fills ()
  "A slot whose command the repository tracks in its bin is not declared."
  (clankos-installation-test-with-garden
      '((".pos/config.yaml" . "projects: projects/\nbin: bin\n")
        ("bin/capture" . "#!/bin/sh\n"))
    (clankos-installation-test--git root "add" "bin/capture")
    (clankos-installation-method-zero root)
    (should (equal '("clankos-bootstrap" "start-up" "wrap-up")
                   (clankos-installation-test--skills
                    (clankos-installation-test--source
                     root clankos-installation-test-repository))))))

(ert-deftest clankos-installation/method-zero-migrates-what-is-installed ()
  "Skills installed from ClankOS, as the lock records them, are what is declared.
The skill of another source is not."
  (clankos-installation-test-with-garden
      `((".pos/config.yaml" . "projects: projects/\n")
        ("skills-lock.json"
         . ,(clankos-installation-test--lock
             '("capture" "ClankaOperatingSystem/clankos")
             '("clankos-lint" "ClankaOperatingSystem/clankos")
             '("other" "acme/other"))))
    (clankos-installation-method-zero root)
    (should (equal '("capture" "clankos-lint")
                   (clankos-installation-test--skills
                    (clankos-installation-test--source
                     root clankos-installation-test-repository))))))

(ert-deftest clankos-installation/method-zero-moves-a-declaration-to-the-image-s-commit ()
  "Where ClankOS is declared, its ref becomes the image's commit and skills are added."
  (clankos-installation-test-with-garden
      `((".pos/config.yaml"
         . ,(concat "projects: projects/\nmethodologies:\n"
                    "  - source: " clankos-installation-test-repository "\n"
                    "    ref: v0.0.1\n    skills: [capture]\n"
                    "    kind: skills-repository\n")))
    (clankos-installation-method-zero root '("clankos-lint"))
    (let ((entry (clankos-installation-test--source
                  root clankos-installation-test-repository)))
      (should (equal clankos-installation-test-commit (alist-get 'ref entry)))
      (should (equal '("capture" "clankos-lint")
                     (clankos-installation-test--skills entry))))))

(ert-deftest clankos-installation/method-zero-refuses-a-skill-the-image-does-not-hold ()
  "A skill named that is not the image's is refused, and nothing is written."
  (clankos-installation-test-with-garden
      '((".pos/config.yaml" . "projects: projects/\n"))
    (should-error (clankos-installation-method-zero root '("no-such-skill")))
    (should (equal "projects: projects/\n"
                   (clankos-installation--read (expand-file-name ".pos/config.yaml" root))))
    (should-not (file-exists-p (expand-file-name ".pos/installation-state.json" root)))))

;;;; The pin

(ert-deftest clankos-installation/apply-needs-method-zero-at-the-image-s-commit ()
  "Apply is refused where the root does not declare ClankOS, or declares it at another ref."
  (clankos-installation-test-with-garden
      '((".pos/config.yaml" . "projects: projects/\n"))
    (let ((nodes (lambda ()
                   (append (alist-get 'nodes (clankos-installation-plan root)) nil))))
      (should (string-match-p
               "Method zero is not declared"
               (cadr (should-error (clankos-installation--pinned root (funcall nodes))))))
      (clankos-installation-test--write
       root `((".pos/config.yaml"
               . ,(concat "projects: projects/\nmethodologies:\n"
                          "  - source: " clankos-installation-test-repository "\n"
                          "    ref: v0.0.1\n    kind: skills-repository\n"))))
      (should (string-match-p
               "declares ClankOS.s skills at v0.0.1"
               (cadr (should-error (clankos-installation--pinned root (funcall nodes))))))
      (clankos-installation-method-zero root)
      (should (equal clankos-installation-test-repository
                     (clankos-installation--pinned root (funcall nodes)))))))

;;;; The installer's input

(ert-deftest clankos-installation/apply-input-refuses-path-methodologies ()
  "A node whose methodologies are a path, the legacy form, refuses apply."
  (clankos-installation-test-with-garden
      '((".pos/config.yaml" . "projects: projects/\nchildren:\n  - path: area\n")
        ("area/.pos/config.yaml" . "projects: projects/\nmethodologies: methodologies/\n"))
    (clankos-installation-method-zero root)
    (should (string-match-p
             "Legacy path methodologies"
             (cadr (should-error (clankos-installation-apply-input root)))))))

(ert-deftest clankos-installation/apply-input-refuses-a-node-that-became-a-repository ()
  "A managed node that has become a repository of its own refuses apply.
Once it is a directory again, it is in the input for cleanup."
  (clankos-installation-test-with-garden
      `((".pos/config.yaml" . "projects: projects/\n")
        ("area/notes.org" . "")
        (".pos/installation-state.json"
         . ,(json-serialize
             '((schema . 1)
               (managed . [((node . "area") (source . "acme/tools")
                            (skill . "tools-lint") (disposition . "remove"))])))))
    (clankos-installation-method-zero root)
    (clankos-installation-test--git (expand-file-name "area" root) "init" "-q")
    (should (string-match-p
             "became a separate repository: area"
             (cadr (should-error (clankos-installation-apply-input root)))))
    (delete-directory (expand-file-name "area/.git" root) t)
    (let ((input (clankos-installation-apply-input root)))
      (should (equal '("cleanup")
                     (delq nil (mapcar (lambda (node)
                                         (and (equal "area" (alist-get 'path node))
                                              (alist-get 'status node)))
                                       (alist-get 'nodes input)))))
      (should (equal clankos-installation-test-repository
                     (alist-get 'clankos (aref (alist-get 'nodes input) 0)))))))

;;;; Ownership

(ert-deftest clankos-installation/the-first-edit-seeds-ownership-from-the-lock ()
  "Without saved state, the skills installed from declared sources become managed.
A skill whose source is not declared is wild-caught and is not."
  (clankos-installation-test-with-garden
      `((".pos/config.yaml"
         . "projects: projects/\nmethodologies:\n  - source: https://github.com/acme/tools.git\n    ref: v1\n")
        ("skills-lock.json"
         . ,(clankos-installation-test--lock
             '("tools-lint" "acme/tools")
             '("stray" "acme/stray"))))
    (clankos-installation-edit root "." "add" '("https://github.com/acme/more.git" "v1"))
    (should (equal '(("." "acme/tools" "tools-lint" nil))
                   (clankos-installation-test--managed root)))))

(ert-deftest clankos-installation/a-removal-saves-remove-or-keep ()
  "Removing a source marks its managed skills remove, or keep with --keep."
  (dolist (keep '(nil t))
    (clankos-installation-test-with-garden
        `((".pos/config.yaml"
           . "projects: projects/\nmethodologies:\n  - source: https://github.com/acme/tools.git\n    ref: v1\n")
          ("skills-lock.json"
           . ,(clankos-installation-test--lock '("tools-lint" "acme/tools"))))
      (clankos-installation-edit root "." "remove" '("https://github.com/acme/tools.git")
                                 keep)
      (should (equal `(("." "acme/tools" "tools-lint" ,(if keep "keep" "remove")))
                     (clankos-installation-test--managed root)))
      (should-not (clankos-installation-test--source
                   root "https://github.com/acme/tools.git")))))

(provide 'clankos-installation-test)
;;; clankos-installation-test.el ends here
