# Sourced by the tests in test/model/, after check.sh. Each script there
# is one group of docs/model.txt's requirements, and each check in it is
# named by one requirement, as a sentence. A requirement poslib holds is
# cited: its test, or its fixture, is in poslib at the commit the image
# pins, and poslib's own suite passed it there. It is not run again. A
# requirement nothing here can test is named with what holds it.
# shellcheck shell=bash

poslib=/usr/local/share/clankos/poslib

# poslib_index: the tests and fixtures of the image's poslib, one per
# line, as "test NAME" and "fixture NAME", read in one container the
# first time a script asks and kept in $own.
poslib_index() {
    [ -s "$own/poslib-index" ] ||
        docker run --rm --entrypoint sh "$CLANKOS_IMAGE" -c '
            sed -n "s/^(ert-deftest \([^ ]*\).*/test \1/p" "$0"/test/*-test.el
            for f in "$0"/fixtures/pos-directory/*.json; do
                f=${f##*/}
                echo "fixture ${f%.json}"
            done' "$poslib" > "$own/poslib-index" 2>/dev/null
    cat "$own/poslib-index"
}

# ert TEST: whether poslib's ERT test TEST is in the image's poslib,
# which pins the commit whose suite passed it.
ert() {
    poslib_index | grep -qxF "test $1"
}

# fixture NAME: whether the fixture fixtures/pos-directory/NAME.json is
# in the image's poslib. poslib's pos-node/a-config-is-read-as-the-
# fixtures-say reads every such fixture as it says.
fixture() {
    ert pos-node/a-config-is-read-as-the-fixtures-say &&
        poslib_index | grep -qxF "fixture $1"
}

# held_by WHAT REQUIREMENT: name a requirement that nothing in clankos
# or poslib tests, and what holds it.
held_by() {
    echo "held  $2 ($1)"
}
