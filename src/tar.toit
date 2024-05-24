// Copyright (C) 2019 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import io

/**
A tar archiver.

Writes the given files into the writer in tar file format.
*/
class Tar:
  writer_ ::= ?

  /**
  Creates a new Tar archiver that writes to the given $writer.

  The $writer should be an $io.Writer, but for compatibility reasons, it can also be an
    "old-style" writer. The old-style writer is deprecated and will be removed in the future.
  */
  constructor writer:
    if writer is io.Writer:
      writer_ = writer
    else:
      writer_ = io.Writer.adapt writer

  /**
  Adds a new "file" to the generated tar-archive.

  This function sets all file attributes to some default values. For example, the
    modification date is set to 0 (epoch time).
  */
  add file-name/string content/io.Data --permissions/int=((6 << 6) | (6 << 3) | 6) -> none:
    add_ file-name content --permissions=permissions

  /**
  Closes the tar stream, and invokes 'close' on the writer if $close-writer is
    true (the default).
  */
  close --close-writer/bool=true:
    // TODO(florian): feels heavy to allocate a new array just to write a bunch of zeros.
    zero-header := ByteArray 512
    writer_.write zero-header
    writer_.write zero-header
    if close-writer: writer_.close

  /**
  Adds the given $file-name with its $content to the tar stream.

  The additional $type parameter is used when filenames don't fit in the standard
    header, and the "LongLink" technique stores the filename as file content.
  The $type parameter must be one of the constants below: $TYPE-NORMAL_ or
    $TYPE-LONG-LINK_.
  */
  add_ file-name/string content/io.Data --type/int=TYPE-NORMAL_ --permissions/int -> none:
    if file-name.size > 100:
      // The file-name is encoded a separate "file".
      add_ "././@LongLink" file-name --type=TYPE-LONG-LINK_ --permissions=permissions
      file-name = file-name.copy 0 100

    file-size := content.byte-size
    file-size-in-octal := file-size.stringify 8

    permissions-in-octal/string := permissions.stringify 8
    permissions-in-octal = permissions-in-octal.pad --left 7 '0'

    header := ByteArray 512
    // See https://en.wikipedia.org/wiki/Tar_(computing)#File_format for the format.
    header.replace 0 file-name
    header.replace 100 permissions-in-octal
    header.replace 124 file-size-in-octal
    // The checksum is computed using spaces. Later it is replaced with the actual values.
    header.replace 148 "        "
    header[156] = type
    header.replace 257 "ustar  "

    checksum := 0
    for i := 0; i < 512; i++:
      checksum += header[i]
    checksum-in-octal := checksum.stringify 8
    // Quoting Wikipedia: [The checksum] is stored as a six digit octal number with
    //   leading zeros followed by a NUL and then a space.
    checksum-pos := 148
    for i := 0; i < 6 - checksum-in-octal.size; i++:
      header[checksum-pos++] = '0'
    header.replace checksum-pos checksum-in-octal.to-byte-array
    header[148 + 6] = '\0'
    header[148 + 7] = ' '

    writer_.write header
    writer_.write content
    // Fill up with zeros to the next 512 boundary.
    last-chunk-size := file-size % 512
    if last-chunk-size != 0:
      missing := 512 - last-chunk-size
      // Reuse the header, to avoid allocating another object.
      // Still need to zero it out.
      for i := 0; i < missing; i++:
        header[i] = '\0'
      writer_.write header 0 missing

  static TYPE-NORMAL_    ::= '0'
  static TYPE-LONG-LINK_ ::= 'L'
