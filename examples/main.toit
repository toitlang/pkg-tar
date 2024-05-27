// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import host.file as file
import tar show *

main:
  stream := file.Stream.for-write "/tmp/toit.tar"
  tar := Tar stream
  tar.add "test2.txt" "456\n"
  tar.add "some-bin.exe" #[0x12, 0x34] --permissions=0b111_000_000
  tar.close --close-writer
