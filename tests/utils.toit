// Copyright (C) 2019 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import monitor
import system
import host.os
import host.file
import host.pipe

tool-path_ tool/string -> string:
  if system.platform != system.PLATFORM-WINDOWS: return tool
  // On Windows, we use the <tool>.exe that comes with Git for Windows.

  // TODO(florian): depending on environment variables is brittle.
  // We should use `SearchPath` (to find `git.exe` in the PATH), or
  // 'SHGetSpecialFolderPath' (to find the default 'Program Files' folder).
  program-files-path := os.env.get "ProgramFiles"
  if not program-files-path:
    // This is brittle, as Windows localizes the name of the folder.
    program-files-path = "C:/Program Files"
  result := "$program-files-path/Git/usr/bin/$(tool).exe"
  if not file.is-file result:
    throw "Could not find $result. Please install Git for Windows"
  return result

tar-path -> string:
  return tool-path_ "tar"

run-tar command flags [generator]:
  pipes := pipe.fork
      true
      pipe.PIPE-CREATED
      pipe.PIPE-CREATED
      pipe.PIPE-INHERITED
      tar-path
      [
        tar-path, command, flags,
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

/**
Extracts the files in the generated file.

Returns the concatenated contents of all extracted files.
*/
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
  name/string
  size/int
  permissions/string

  constructor --.name --.size --.permissions:

list-with-tar-bin [generator] -> List/*<TarEntry>*/:
  listing := inspect-with-tar-bin generator
  lines := (listing.trim --right "\n").split "\n"
  return lines.map: |line|
    // A line looks something like:
    // Linux: -rw-rw-r-- 0/0               5 1970-01-01 01:00 /foo
    // Mac:   -rw-rw-r--  0 0      0           5 Jan  1  1970 /foo
    permissions-index := 0
    name-index := system.platform == system.PLATFORM-MACOS ? 8 : 5
    size-index := system.platform == system.PLATFORM-MACOS ? 4 : 2
    components := split-fields line
    file-name := components[name-index]
    size := int.parse components[size-index]
    permissions := components[permissions-index]
    TarEntry --name=file-name --size=size --permissions=permissions

