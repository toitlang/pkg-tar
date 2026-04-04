// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import host.file
import host.directory
import tar

/**
Demonstrates the convenience functions for archiving a directory
  and extracting a tar archive.
*/
main:
  tmp := directory.mkdtemp "/tmp/tar-example-"

  // Create a directory structure to archive.
  source := "$tmp/source"
  create-sample-directory source

  // Archive the directory into a tar file.
  archive-path := "$tmp/archive.tar"
  stream := file.Stream.for-write archive-path
  tar.create --writer=stream.out --source=source
  stream.close
  print "Created $archive-path from $source"

  // Extract the tar file into a new directory.
  target := "$tmp/target"
  directory.mkdir target
  stream = file.Stream.for-read archive-path
  tar.extract --reader=stream.in --directory=target
  stream.close
  print "Extracted to $target"

  // Verify the extracted files.
  print (file.read-contents "$target/hello.txt").to-string
  print (file.read-contents "$target/subdir/nested.txt").to-string

  directory.rmdir --recursive tmp

create-sample-directory path/string:
  directory.mkdir path
  file.write-contents "Hello from Toit!\n" --path="$path/hello.txt"
  file.write-contents "Some data\n" --path="$path/data.bin"
  sub := "$path/subdir"
  directory.mkdir sub
  file.write-contents "Nested file\n" --path="$sub/nested.txt"
