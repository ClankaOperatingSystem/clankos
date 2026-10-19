# Sourced by the tests in test/model/, after check.sh. Each script there
# is one group of docs/model.txt's requirements, and each check in it is
# named by one requirement, as a sentence. A requirement poslib holds is
# checked by running poslib's test in the image, at the commit the image
# pins; a requirement nothing here can test is named with what holds it.
# shellcheck shell=bash

poslib=/usr/local/share/clankos/poslib

# image_emacs ARG ...: run the image's Emacs in batch, with poslib and
# its tests on the load path.
image_emacs() {
    docker run --rm --entrypoint emacs "$CLANKOS_IMAGE" -Q --batch \
        -l /usr/local/share/clankos/lisp/clankos-packages.el \
        -L "$poslib/test" -l ert "$@"
}

# ert TEST: whether poslib's ERT test TEST, of the file its prefix
# names, is there and passes.
ert() {
    image_emacs -l "${1%%/*}-test" --eval "(progn
        (unless (ert-test-boundp '$1) (kill-emacs 2))
        (ert-run-tests-batch-and-exit '(member $1)))" > /dev/null 2>&1
}

# fixture NAME: whether poslib's configuration reader reads the fixture
# fixtures/pos-directory/NAME.json as it says: as its configuration, or
# refused with its kind of refusal.
fixture() {
    image_emacs -l pos-node-test --eval "(let-alist (pos-fixture \"pos-directory\" \"$1\")
        (kill-emacs
         (if (if .refused
                 (equal .refused
                        (condition-case err
                            (progn (pos-node-read-config .yaml) \"accepted\")
                          (pos-node-refused (symbol-name (nth 1 err)))))
               (equal (pos-node-test-sorted .config)
                      (pos-node-test-sorted (pos-node-read-config .yaml))))
             0 1)))" > /dev/null 2>&1
}

# held_by WHAT REQUIREMENT: name a requirement that nothing in clankos
# or poslib tests, and what holds it.
held_by() {
    echo "held  $2 ($1)"
}
