// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import host.file as file
import tar

/**
Reads a tar archive and prints each entry's name, size, and content.

Run the 'write.toit' example first to create the tar file.
*/
main:
  stream := file.Stream.for-read "/tmp/toit.tar"
  reader := tar.Reader stream.in
  reader.do: |header/tar.Header content/ByteArray|
    print "$(header.name) ($(header.size) bytes)"
    print "  $content.to-string"
  stream.close
