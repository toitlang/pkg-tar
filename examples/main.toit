// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import host.file as file
import tar show *

main:
  tar := Tar (file.Stream "/tmp/toit.tar" file.CREAT | file.WRONLY 0x1ff)
  tar.add "test2.txt" "456\n"
  tar.add "012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789" "123\n"
  tar.close
