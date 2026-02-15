// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar show *
import expect show *
import tar show *
import io

class MemoryWriter extends io.Writer:
  buffer_/ByteArray := ByteArray 0

  try-write_ data/io.Data from/int=0 to/int=data.byte-size -> int:
    // If data is a string, convert to byte array.
    bytes/ByteArray := ?
    if data is string:
      bytes = (data as string).to-byte-array
    else:
      bytes = data as ByteArray
    // Append to buffer.
    buffer_ = buffer_ + bytes[from..to]
    return to - from

  close:
    // Do nothing.

  bytes -> ByteArray:
    return buffer_

main:
  test-properties

test-properties:
  writer := MemoryWriter
  tar := TarWriter writer

  mtime := Time.epoch + (Duration --s=1234567890)

  tar.add "test.txt" "content"
      --permissions=420 // 0644
      --uid=1000
      --gid=1000
      --mtime=mtime
      --type=TarWriter.TYPE-REGULAR-FILE
      --user-name="user"
      --group-name="group"
      --device-major=1
      --device-minor=2

  tar.close

  bytes := writer.bytes
  // Header is first 512 bytes.
  header := bytes[0..512]

  // Helper to parse octal string from header.
  parse-octal := : |offset length|
    str-bytes := header[offset..offset+length]
    // Find null terminator or take full length.
    end := str-bytes.index-of 0
    if end == -1: end = length
    str := str-bytes[0..end].to-string
    int.parse str --radix=8

  // Helper to parse string from header.
  parse-string := : |offset length|
    str-bytes := header[offset..offset+length]
    end := str-bytes.index-of 0
    if end == -1: end = length
    str-bytes[0..end].to-string

  // Verify fields.
  expect-equals "test.txt" (parse-string.call 0 100)
  expect-equals 420 (parse-octal.call 100 8)
  expect-equals 1000 (parse-octal.call 108 8)
  expect-equals 1000 (parse-octal.call 116 8)
  expect-equals 7 (parse-octal.call 124 12) // "content".size = 7
  expect-equals 1234567890 (parse-octal.call 136 12)
  expect-equals TarWriter.TYPE-REGULAR-FILE header[156]
  expect-equals "ustar  " (parse-string.call 257 8)
  expect-equals "user" (parse-string.call 265 32)
  expect-equals "group" (parse-string.call 297 32)
  expect-equals 1 (parse-octal.call 329 8)
  expect-equals 2 (parse-octal.call 337 8)
