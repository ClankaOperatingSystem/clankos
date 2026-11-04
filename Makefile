# make check: the tests that need no container, on the host. The Lisp
# of lisp/ is tested with ERT against poslib at the commit the
# Dockerfile pins, fetched into _deps/poslib with what it requires, and
# the rules of clankos-skills/ with node's test runner. The tests that
# need Docker are test/run's.

EMACS ?= emacs
NODE ?= node
POSLIB_URL = https://github.com/ClankaOperatingSystem/poslib.git
POSLIB_COMMIT := $(shell sed -n 's/^ARG POSLIB_COMMIT=//p' Dockerfile)
POSLIB = _deps/poslib

.PHONY: check lisp node deps clean

check: lisp node

# poslib at POSLIB_COMMIT, fetched again if it is at another; then the
# packages poslib requires, by its own make deps.
deps:
	@if [ "$$(git -C $(POSLIB) rev-parse HEAD 2>/dev/null)" != "$(POSLIB_COMMIT)" ]; then \
	     rm -rf $(POSLIB) && git init -q $(POSLIB) \
	  && git -C $(POSLIB) fetch -q --depth 1 $(POSLIB_URL) $(POSLIB_COMMIT) \
	  && git -C $(POSLIB) checkout -q FETCH_HEAD; \
	fi
	@$(MAKE) -s -C $(POSLIB) deps

lisp: deps
	$(EMACS) -Q --batch \
	  $(foreach dir,$(wildcard $(POSLIB)/_deps/* $(POSLIB)/_deps/*/lisp),-L $(dir)) \
	  -L $(POSLIB)/lisp -L lisp -L test/lisp -l ert \
	  $(foreach file,$(wildcard test/lisp/*-test.el),-l $(file)) \
	  -f ert-run-tests-batch-and-exit

node:
	$(NODE) --test 'clankos-skills/test/*.test.mjs'

clean:
	rm -rf _deps
