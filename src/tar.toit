// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import io

/**
A tar archiver.

Writes the given files into the writer in tar file format.
*/
class TarWriter:
  static TYPE-REGULAR-FILE ::= '0'
  static TYPE-LINK         ::= '1'
  static TYPE-SYMBOLIC-LINK ::= '2'
  static TYPE-CHARACTER-DEVICE ::= '3'
  static TYPE-BLOCK-DEVICE ::= '4'
  static TYPE-DIRECTORY    ::= '5'
  static TYPE-FIFO         ::= '6'

  static TYPE-NORMAL_    ::= '0'
  static TYPE-LONG-LINK_ ::= 'L'

  writer_/io.Writer

  /**
  Creates a new Tar archiver that writes to the given $writer.
  */
  constructor writer/io.Writer:
    writer_ = writer

  /**
  Adds a new "file" to the generated tar-archive.

  This function sets all file attributes to some default values. For example, the
    modification date is set to 0 (epoch time).
  */
  add file-name/string content/io.Data
      --permissions/int=((6 << 6) | (6 << 3) | 6)
      --uid/int=0
      --gid/int=0
      --mtime/Time?=null
      --type/int=TYPE-REGULAR-FILE
      --user-name/string=""
      --group-name/string=""
      --device-major/int=0
      --device-minor/int=0
      -> none:
    add_ file-name content
        --permissions=permissions
        --uid=uid
        --gid=gid
        --mtime=mtime
        --type=type
        --user-name=user-name
        --group-name=group-name
        --device-major=device-major
        --device-minor=device-minor

  /**
  Closes the tar stream, but does not close the writer.
  */
  close:
    // TODO(florian): feels heavy to allocate a new array just to write a bunch of zeros.
    zero-header := ByteArray 512
    writer_.write zero-header
    writer_.write zero-header

  /**
  Adds the given $file-name with its $content to the tar stream.

  The additional $type parameter is used when filenames don't fit in the standard
    header, and the "LongLink" technique stores the filename as file content.
  The $type parameter must be one of the constants below: $TYPE-NORMAL_ or
    $TYPE-LONG-LINK_.
  */
  add_ file-name/string content/io.Data
      --permissions/int
      --uid/int=0
      --gid/int=0
      --mtime/Time?=null
      --type/int=TYPE-REGULAR-FILE
      --user-name/string=""
      --group-name/string=""
      --device-major/int=0
      --device-minor/int=0
      -> none:
    if file-name.size > 100:
      // The file-name is encoded a separate "file".
      add_ "././@LongLink" file-name
          --permissions=permissions
          --uid=uid
          --gid=gid
          --mtime=mtime
          --type=TYPE-LONG-LINK_
          --user-name=user-name
          --group-name=group-name
          --device-major=device-major
          --device-minor=device-minor

      file-name = file-name.copy 0 100

    file-size := content.byte-size
    file-size-in-octal := file-size.to-string --radix=8

    permissions-in-octal/string := permissions.to-string --radix=8
    permissions-in-octal = permissions-in-octal.pad --left 7 '0'

    uid-in-octal/string := uid.to-string --radix=8
    uid-in-octal = uid-in-octal.pad --left 7 '0'

    gid-in-octal/string := gid.to-string --radix=8
    gid-in-octal = gid-in-octal.pad --left 7 '0'

    mtime-val := mtime ? (mtime.ms-since-epoch / 1000) : 0
    mtime-in-octal/string := mtime-val.to-string --radix=8
    mtime-in-octal = mtime-in-octal.pad --left 11 '0'

    devmajor-in-octal/string := device-major.to-string --radix=8
    devmajor-in-octal = devmajor-in-octal.pad --left 7 '0'

    devminor-in-octal/string := device-minor.to-string --radix=8
    devminor-in-octal = devminor-in-octal.pad --left 7 '0'

    header := ByteArray 512
    // See https://en.wikipedia.org/wiki/Tar_(computing)#File_format for the format.
    header.replace 0 file-name
    header.replace 100 permissions-in-octal
    header.replace 108 uid-in-octal
    header.replace 116 gid-in-octal
    header.replace 124 file-size-in-octal
    header.replace 136 mtime-in-octal
    // The checksum is computed using spaces. Later it is replaced with the actual values.
    header.replace 148 "        "
    header[156] = type
    header.replace 257 "ustar  "
    header.replace 265 (limit-string_ user-name 32)
    header.replace 297 (limit-string_ group-name 32)
    header.replace 329 devmajor-in-octal
    header.replace 337 devminor-in-octal

    checksum := 0
    for i := 0; i < 512; i++:
      checksum += header[i]
    checksum-in-octal := checksum.to-string --radix=8
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

  static limit-string_ str/string limit/int -> string:
    if str.size <= limit: return str
    return str[..limit]

/**
A header entry in a tar archive.
*/
class TarHeader:
  /** The name of the file. */
  name/string
  /** The file permissions. */
  permissions/int
  /** The user ID. */
  uid/int
  /** The group ID. */
  gid/int
  /** The size of the file content in bytes. */
  size/int
  /** The modification time. */
  mtime/Time
  /** The type of the entry. See $TarWriter.TYPE-REGULAR-FILE and friends. */
  type/int
  /** The user name. */
  user-name/string
  /** The group name. */
  group-name/string
  /** The device major number. */
  device-major/int
  /** The device minor number. */
  device-minor/int

  constructor
      --.name
      --.permissions
      --.uid
      --.gid
      --.size
      --.mtime
      --.type
      --.user-name
      --.group-name
      --.device-major
      --.device-minor:

/**
A tar reader.

Reads entries from a tar archive provided as an $io.Reader.
*/
class TarReader:
  reader_/io.Reader

  /**
  Creates a new tar reader that reads from the given $reader.
  */
  constructor reader/io.Reader:
    reader_ = reader

  /**
  Iterates over all entries in the tar archive.

  Calls the given $block with a $TarHeader and a $ByteArray for each entry.
  LongLink entries are handled transparently: the block is only called for
    actual file entries with their full (long) name.
  */
  do [block]:
    long-name/string? := null
    while true:
      if not reader_.try-ensure-buffered 512: return
      header-bytes := reader_.read-bytes 512

      // Two consecutive zero blocks signal end of archive.
      if is-zero-block_ header-bytes: return

      name := long-name or (parse-string_ header-bytes 0 100)
      long-name = null

      file-size := parse-octal_ header-bytes 124 12
      permissions := parse-octal_ header-bytes 100 8
      uid := parse-octal_ header-bytes 108 8
      gid := parse-octal_ header-bytes 116 8
      mtime-s := parse-octal_ header-bytes 136 12
      type := header-bytes[156]
      user-name := parse-string_ header-bytes 265 32
      group-name := parse-string_ header-bytes 297 32
      device-major := parse-octal_ header-bytes 329 8
      device-minor := parse-octal_ header-bytes 337 8

      // Read content (padded to 512-byte boundary).
      content := ByteArray 0
      if file-size > 0:
        reader_.ensure-buffered file-size
        content = reader_.read-bytes file-size
        padding := (512 - (file-size % 512)) % 512
        if padding > 0: reader_.skip padding

      if type == TarWriter.TYPE-LONG-LINK_:
        // LongLink: content is the real filename (may have trailing null).
        long-name-bytes := content
        // Strip trailing null bytes.
        end := long-name-bytes.size
        while end > 0 and long-name-bytes[end - 1] == 0: end--
        long-name = long-name-bytes[..end].to-string
        continue

      mtime := Time.epoch + (Duration --s=mtime-s)
      tar-header := TarHeader
          --name=name
          --permissions=permissions
          --uid=uid
          --gid=gid
          --size=file-size
          --mtime=mtime
          --type=type
          --user-name=user-name
          --group-name=group-name
          --device-major=device-major
          --device-minor=device-minor
      block.call tar-header content

  static is-zero-block_ bytes/ByteArray -> bool:
    bytes.do: if it != 0: return false
    return true

  static parse-octal_ bytes/ByteArray offset/int length/int -> int:
    end := offset + length
    // Find the end of the octal string (null or space terminated).
    while end > offset and (bytes[end - 1] == 0 or bytes[end - 1] == ' '): end--
    if end == offset: return 0
    str := bytes[offset..end].to-string
    return int.parse str --radix=8

  static parse-string_ bytes/ByteArray offset/int length/int -> string:
    end := offset + length
    // Find null terminator.
    for i := offset; i < end; i++:
      if bytes[i] == 0:
        end = i
        break
    return bytes[offset..end].to-string
