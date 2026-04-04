// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar show *
import io

import .utils

LONG-NAME ::= "012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
main:
  listing := list-with-tar-bin: | writer/io.Writer |
    tar := TarWriter writer
    tar.add LONG-NAME "some-content"
    tar.close

  expect-equals 1 listing.size
  expect-equals LONG-NAME listing.first.name
