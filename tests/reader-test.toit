// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar show *
import io

main:
  test-basic-roundtrip
  test-empty-archive
  test-empty-file
  test-large-file
  test-multiple-files
  test-long-name
  test-properties

/**
Helper that writes a tar archive to a buffer and returns the bytes.
*/
write-tar [block] -> ByteArray:
  buffer := io.Buffer
  tar := TarWriter buffer
  block.call tar
  tar.close
  return buffer.bytes

test-basic-roundtrip:
  bytes := write-tar: |tar/TarWriter|
    tar.add "hello.txt" "Hello, World!"

  reader := TarReader (io.Reader bytes)
  count := 0
  reader.do: |header/TarHeader content/ByteArray|
    count++
    expect-equals "hello.txt" header.name
    expect-equals 13 header.size
    expect-equals "Hello, World!" content.to-string
    expect-equals TarWriter.TYPE-REGULAR-FILE header.type
  expect-equals 1 count

test-empty-archive:
  bytes := write-tar: |tar/TarWriter|
    null  // Add nothing.

  reader := TarReader (io.Reader bytes)
  count := 0
  reader.do: |header/TarHeader content/ByteArray|
    count++
  expect-equals 0 count

test-empty-file:
  bytes := write-tar: |tar/TarWriter|
    tar.add "empty.txt" ""

  reader := TarReader (io.Reader bytes)
  count := 0
  reader.do: |header/TarHeader content/ByteArray|
    count++
    expect-equals "empty.txt" header.name
    expect-equals 0 header.size
    expect-equals 0 content.size
  expect-equals 1 count

test-large-file:
  large-content := ByteArray 10000: 'A' + it % 50
  bytes := write-tar: |tar/TarWriter|
    tar.add "large.bin" large-content

  reader := TarReader (io.Reader bytes)
  count := 0
  reader.do: |header/TarHeader content/ByteArray|
    count++
    expect-equals "large.bin" header.name
    expect-equals 10000 header.size
    expect-equals large-content content
  expect-equals 1 count

test-multiple-files:
  files := {
    "first.txt": "AAA",
    "second.txt": "BBBB",
    "third.txt": "",
    "fourth.txt": "CCCCCCCC",
  }

  bytes := write-tar: |tar/TarWriter|
    files.do: |name content|
      tar.add name content

  reader := TarReader (io.Reader bytes)
  found := {:}
  reader.do: |header/TarHeader content/ByteArray|
    found[header.name] = content.to-string

  expect-equals files.size found.size
  files.do: |name expected-content|
    expect-equals expected-content found[name]

test-long-name:
  long-name := "a" * 200
  bytes := write-tar: |tar/TarWriter|
    tar.add long-name "content"

  reader := TarReader (io.Reader bytes)
  count := 0
  reader.do: |header/TarHeader content/ByteArray|
    count++
    expect-equals long-name header.name
    expect-equals "content" content.to-string
  expect-equals 1 count

test-properties:
  mtime := Time.epoch + (Duration --s=1234567890)
  bytes := write-tar: |tar/TarWriter|
    tar.add "test.txt" "content"
        --permissions=0b110_100_100
        --uid=1000
        --gid=1000
        --mtime=mtime
        --type=TarWriter.TYPE-REGULAR-FILE
        --user-name="user"
        --group-name="group"
        --device-major=1
        --device-minor=2

  reader := TarReader (io.Reader bytes)
  count := 0
  reader.do: |header/TarHeader content/ByteArray|
    count++
    expect-equals "test.txt" header.name
    expect-equals 0b110_100_100 header.permissions
    expect-equals 1000 header.uid
    expect-equals 1000 header.gid
    expect-equals 7 header.size
    expect-equals 1234567890 (header.mtime.ms-since-epoch / 1000)
    expect-equals TarWriter.TYPE-REGULAR-FILE header.type
    expect-equals "user" header.user-name
    expect-equals "group" header.group-name
    expect-equals 1 header.device-major
    expect-equals 2 header.device-minor
    expect-equals "content" content.to-string
  expect-equals 1 count
