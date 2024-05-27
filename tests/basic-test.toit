// Copyright (C) 2019 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar show *
import io

import .utils

test-tar contents:
  create-tar := : |writer/io.Writer|
    tar := Tar writer
    contents.do: |file-name file-contents|
      tar.add file-name file-contents
    tar.close

  listing := list-with-tar-bin create-tar
  expect-equals contents.size listing.size
  listing.do: |entry|
    expect (contents.contains entry.name)
    expect-equals entry.size contents[entry.name].size

  concatenated-content := extract create-tar
  expected := ""
  contents.do --values:
    expected += it
  expect-equals expected concatenated-content

create-huge-contents -> string:
  bytes := ByteArray 10000
  for i := 0; i < bytes.size; i++:
    bytes[i] = 'A' + i % 50
  return bytes.to-string

main:
  test-tar {
    "/foo": "12345",
  }

  test-tar {
    "/foo": "12345",
    "bar": "1",
  }

  test-tar {
    "/foo": "12345",
    "bar": "",
  }
  test-tar {
    "/foo/bar": "12345",
    "huge_file": create-huge-contents,
    "empty": "",
    "gee": "gee",
  }
