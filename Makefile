# Copyright (C) 2024 Toitware ApS.
# Use of this source code is governed by a Zero-Clause BSD license that can
# be found in the tests/LICENSE file.

.PHONY: all
all: test

.PHONY: test
test:
	@toit pkg install --project-root tests;
	@for f in tests/*-test.toit; do \
		toit $$f; \
	done
