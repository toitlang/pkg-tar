// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import io
import tar

/**
Creates a tar archive in memory and reads it back without
  touching the file system.
*/
main:
  // Write a tar archive into an in-memory buffer.
  buffer := io.Buffer
  writer := tar.Writer buffer
  writer.add "greeting.txt" "Hello, World!\n"
  writer.add "numbers.txt" "one\ntwo\nthree\n"
  writer.close

  print "Archive size: $buffer.size bytes"

  // Read the archive back from the buffer.
  reader := tar.Reader (io.Reader buffer.bytes)
  reader.do: |header/tar.Header content/ByteArray|
    print "$(header.name): $(content.to-string.trim)"
