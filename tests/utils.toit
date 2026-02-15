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
  process := pipe.fork
      --use-path
      --create-stdin
      --create-stdout
      tar-path
      [tar-path, command, flags]

  to := process.stdin
  from := process.stdout
  process.wait-ignore

  // Process STDOUT in subprocess, so we don't block the tar process.
  latch := monitor.Latch
  task::
    reader := from.in
    reader.buffer-all
    result := reader.read-string reader.buffered-size
    latch.set result

  generator.call to.out
  to.close

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
      "x"   // extract.
      "-PO" // P for absolute paths, to stdout.
      generator

split-fields_ line/string -> List/*<string>*/:
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
  permissions/int
  owner/string
  group/string
  mtime/string

  constructor --.name --.size --.permissions --.owner --.group --.mtime:

parse-permissions_ str/string -> int:
  res := 0
  // Expected format: -rwxrwxrwx (10 chars).
  if str.size < 10: return 0

  // User.
  if str[1] == 'r': res |= 0b100_000_000
  if str[2] == 'w': res |= 0b010_000_000
  if str[3] == 'x': res |= 0b001_000_000

  // Group.
  if str[4] == 'r': res |= 0b000_100_000
  if str[5] == 'w': res |= 0b000_010_000
  if str[6] == 'x': res |= 0b000_001_000

  // Other.
  if str[7] == 'r': res |= 0b000_000_100
  if str[8] == 'w': res |= 0b000_000_010
  if str[9] == 'x': res |= 0b000_000_001

  return res

list-with-tar-bin [generator] -> List/*<TarEntry>*/:
  listing := inspect-with-tar-bin generator
  lines := (listing.trim --right "\n").split "\n"
  return lines.map: |line|
    // A line looks something like:
    // Linux: -rw-rw-r-- 1000/1000          5 1970-01-01 01:00 /foo
    // Mac:   -rw-rw-r--  0 1000 1000      5 Jan  1  1970 /foo
    // Mac (recent): -rw-rw-r--  0 1000 1000      5 Jan  1 01:00 /foo
    components := split-fields_ line

    name-index := 0
    size-index := 0
    mtime-string := ""
    user := ""
    group := ""

    permissions := parse-permissions_ components[0]

    if system.platform == system.PLATFORM-MACOS:
      name-index = 8
      size-index = 4
      user = components[2]
      group = components[3]
      // Date is at 5, 6, 7 (e.g., "Jan", "1", "1970" or "Jan", "1", "01:00").
      mtime-string = "$components[5] $components[6] $components[7]"
    else:
      name-index = 5
      size-index = 2
      parts := components[1].split "/"
      user = parts[0]
      group = parts[1]
      // Date is at 3, 4 (e.g., "1970-01-01", "01:00")
      mtime-string = "$components[3] $components[4]"

    file-name := components[name-index]
    size := int.parse components[size-index]

    TarEntry
        --name=file-name
        --size=size
        --permissions=permissions
        --owner=user
        --group=group
        --mtime=mtime-string
