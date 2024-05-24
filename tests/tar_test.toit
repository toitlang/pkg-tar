// Copyright (C) 2019 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar show *
import host.pipe
import host.file
import io
import monitor
import system show platform PLATFORM-FREERTOS PLATFORM-MACOS

run-tar command flags [generator]:
  pipes := pipe.fork
      true
      pipe.PIPE-CREATED
      pipe.PIPE-CREATED
      pipe.PIPE-INHERITED
      "tar"
      [
        "tar", command, flags,
      ]

  to/pipe.OpenPipe := pipes[0]
  from/pipe.OpenPipe := pipes[1]
  pid := pipes[3]
  pipe.dont-wait-for pid

  // Process STDOUT in subprocess, so we don't block the tar process.
  latch := monitor.Latch
  task::
    reader := from.in
    reader.buffer-all
    result := reader.read-string reader.buffered-size
    latch.set result

  generator.call to.out

  return latch.get

inspect-with-tar-bin [generator]:
  return run-tar
      "t"   // list
      "-Pv" // P for absolute paths, verbose
      generator

/// Extracts the files in the generated file.
///
/// Returns the concatenated contents of all extracted files.
extract [generator]:
  return run-tar
      "x"   // extract
      "-PO" // P for absolute paths, to stdout
      generator

split-fields line/string -> List/*<string>*/:
  result := []
  start-pos := 0
  last-was-space := true
  for i := 0; i <= line.size; i++:
    c := i == line.size ? ' ' : line[i]
    if c == ' ' and not last-was-space:
      result.add (line.copy start-pos i)
    if c != ' ' and last-was-space:
      start-pos = i
    last-was-space = c == ' '
  return result

class TarEntry:
  name / string ::= ?
  size / int ::= -1

  constructor .name .size:

list-with-tar-bin [generator] -> List/*<TarEntry>*/:
  listing := inspect-with-tar-bin generator
  lines := (listing.trim --right "\n").split "\n"
  return lines.map: |line|
    // A line looks something like:
    // Linux: -rw-rw-r-- 0/0               5 1970-01-01 01:00 /foo
    // Mac:   -rw-rw-r--  0 0      0           5 Jan  1  1970 /foo
    name-index := platform == PLATFORM-MACOS ? 8 : 5
    size-index := platform == PLATFORM-MACOS ? 4 : 2
    components := split-fields line
    file-name := components[name-index]
    size := int.parse components[size-index]
    TarEntry file-name size

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
  // FreeRTOS doesn't have `tar`.
  if platform == PLATFORM-FREERTOS: return

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
