// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar show *
import io

import .utils

TESTS := {
  "-rwx------": 0b111_000_000,
  "-------rwx": 0b000_000_111,
  "-rwxrwxrwx": 0b111_111_111,
  "-r--------": 0b100_000_000,
  "----r-----": 0b000_100_000,
  "-------r--": 0b000_000_100,
  "--w-------": 0b010_000_000,
  "-----w----": 0b000_010_000,
  "--------w-": 0b000_000_010,
  "---x------": 0b001_000_000,
  "------x---": 0b000_001_000,
  "---------x": 0b000_000_001,
}

main:
  listing := list-with-tar-bin: | writer/io.Writer |
    tar := TarWriter writer
    TESTS.do: | output/string permissions/int |
      tar.add "file-$output" "some-content" --permissions=permissions
    tar.close

  expect-equals TESTS.size listing.size
  listing.do: | entry/TarEntry |
    expect-equals entry.permissions (entry.name.trim --left "file-")
