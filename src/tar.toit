// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import io

TYPE-REGULAR-FILE     ::= '0'
TYPE-LINK             ::= '1'
TYPE-SYMBOLIC-LINK    ::= '2'
TYPE-CHARACTER-DEVICE ::= '3'
TYPE-BLOCK-DEVICE     ::= '4'
TYPE-DIRECTORY        ::= '5'
TYPE-FIFO             ::= '6'

TYPE-LONG-LINK_ ::= 'L'

HEADER-SIZE_ ::= 512

/**
A header entry in a tar archive.

The header is backed by the raw 512-byte header block. Field values are
  parsed on demand from the underlying bytes.

See https://en.wikipedia.org/wiki/Tar_(computing)#File_format for the format.
*/
class Header:
  static NAME-OFFSET_         ::= 0
  static NAME-LENGTH_         ::= 100
  static PERMISSIONS-OFFSET_  ::= 100
  static PERMISSIONS-LENGTH_  ::= 8
  static UID-OFFSET_          ::= 108
  static UID-LENGTH_          ::= 8
  static GID-OFFSET_          ::= 116
  static GID-LENGTH_          ::= 8
  static SIZE-OFFSET_         ::= 124
  static SIZE-LENGTH_         ::= 12
  static MTIME-OFFSET_        ::= 136
  static MTIME-LENGTH_        ::= 12
  static CHECKSUM-OFFSET_     ::= 148
  static CHECKSUM-LENGTH_     ::= 8
  static TYPE-OFFSET_         ::= 156
  static MAGIC-OFFSET_        ::= 257
  static MAGIC-LENGTH_        ::= 8
  static USER-NAME-OFFSET_    ::= 265
  static USER-NAME-LENGTH_    ::= 32
  static GROUP-NAME-OFFSET_   ::= 297
  static GROUP-NAME-LENGTH_   ::= 32
  static DEVICE-MAJOR-OFFSET_ ::= 329
  static DEVICE-MAJOR-LENGTH_ ::= 8
  static DEVICE-MINOR-OFFSET_ ::= 337
  static DEVICE-MINOR-LENGTH_ ::= 8

  bytes_/ByteArray
  long-name_/string?

  /**
  Creates a new header with the given fields.

  The $name may be longer than 100 bytes. In that case the $Writer
    automatically uses the GNU LongLink extension.
  */
  constructor
      --name/string
      --permissions/int=((6 << 6) | (6 << 3) | 6)
      --uid/int=0
      --gid/int=0
      --size/int=0
      --mtime/Time=Time.epoch
      --type/int=TYPE-REGULAR-FILE
      --user-name/string=""
      --group-name/string=""
      --device-major/int=0
      --device-minor/int=0:
    long-name_ = name.size > NAME-LENGTH_ ? name : null
    bytes_ = ByteArray HEADER-SIZE_
    bytes_.replace NAME-OFFSET_ (limit-string_ name NAME-LENGTH_)
    write-octal_ bytes_ PERMISSIONS-OFFSET_ (PERMISSIONS-LENGTH_ - 1) permissions
    write-octal_ bytes_ UID-OFFSET_ (UID-LENGTH_ - 1) uid
    write-octal_ bytes_ GID-OFFSET_ (GID-LENGTH_ - 1) gid
    write-octal_ bytes_ SIZE-OFFSET_ SIZE-LENGTH_ size
    mtime-val := mtime.ms-since-epoch / 1000
    write-octal_ bytes_ MTIME-OFFSET_ (MTIME-LENGTH_ - 1) mtime-val
    // The checksum is computed using spaces. Later it is replaced with the actual values.
    bytes_.replace CHECKSUM-OFFSET_ "        "
    bytes_[TYPE-OFFSET_] = type
    bytes_.replace MAGIC-OFFSET_ "ustar  "
    bytes_.replace USER-NAME-OFFSET_ (limit-string_ user-name USER-NAME-LENGTH_)
    bytes_.replace GROUP-NAME-OFFSET_ (limit-string_ group-name GROUP-NAME-LENGTH_)
    write-octal_ bytes_ DEVICE-MAJOR-OFFSET_ (DEVICE-MAJOR-LENGTH_ - 1) device-major
    write-octal_ bytes_ DEVICE-MINOR-OFFSET_ (DEVICE-MINOR-LENGTH_ - 1) device-minor
    compute-checksum_

  /**
  Creates a $Header from the given 512-byte $header-bytes.

  If $long-name is provided, it overrides the name field in the header
    (used for the GNU LongLink extension).
  */
  constructor.from-bytes header-bytes/ByteArray --long-name/string?=null:
    bytes_ = header-bytes
    long-name_ = long-name

  /** The name of the file. */
  name -> string:
    if long-name_: return long-name_
    return parse-string_ bytes_ NAME-OFFSET_ NAME-LENGTH_

  /** The file permissions. */
  permissions -> int:
    return parse-octal_ bytes_ PERMISSIONS-OFFSET_ PERMISSIONS-LENGTH_

  /** The user ID. */
  uid -> int:
    return parse-octal_ bytes_ UID-OFFSET_ UID-LENGTH_

  /** The group ID. */
  gid -> int:
    return parse-octal_ bytes_ GID-OFFSET_ GID-LENGTH_

  /** The size of the file content in bytes. */
  size -> int:
    return parse-octal_ bytes_ SIZE-OFFSET_ SIZE-LENGTH_

  /** The modification time. */
  mtime -> Time:
    mtime-s := parse-octal_ bytes_ MTIME-OFFSET_ MTIME-LENGTH_
    return Time.epoch + (Duration --s=mtime-s)

  /**
  The type of the entry.
  See $TYPE-REGULAR-FILE and friends.
  */
  type -> int:
    return bytes_[TYPE-OFFSET_]

  /** The user name. */
  user-name -> string:
    return parse-string_ bytes_ USER-NAME-OFFSET_ USER-NAME-LENGTH_

  /** The group name. */
  group-name -> string:
    return parse-string_ bytes_ GROUP-NAME-OFFSET_ GROUP-NAME-LENGTH_

  /** The device major number. */
  device-major -> int:
    return parse-octal_ bytes_ DEVICE-MAJOR-OFFSET_ DEVICE-MAJOR-LENGTH_

  /** The device minor number. */
  device-minor -> int:
    return parse-octal_ bytes_ DEVICE-MINOR-OFFSET_ DEVICE-MINOR-LENGTH_

  /** The raw 512-byte header block. */
  to-byte-array -> ByteArray:
    return bytes_

  /**
  Whether the given 512-byte block is all zeros (indicating end of archive).
  */
  static is-zero-block_ bytes/ByteArray -> bool:
    bytes.do: if it != 0: return false
    return true

  compute-checksum_ -> none:
    checksum := 0
    for i := 0; i < HEADER-SIZE_; i++:
      checksum += bytes_[i]
    checksum-in-octal := checksum.to-string --radix=8
    // Quoting Wikipedia: [The checksum] is stored as a six digit octal number with
    //   leading zeros followed by a NUL and then a space.
    checksum-pos := CHECKSUM-OFFSET_
    for i := 0; i < 6 - checksum-in-octal.size; i++:
      bytes_[checksum-pos++] = '0'
    bytes_.replace checksum-pos checksum-in-octal.to-byte-array
    bytes_[CHECKSUM-OFFSET_ + 6] = '\0'
    bytes_[CHECKSUM-OFFSET_ + 7] = ' '

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

  static write-octal_ header/ByteArray offset/int width/int value/int -> none:
    str := value.to-string --radix=8
    str = str.pad --left width '0'
    header.replace offset str

  static limit-string_ str/string limit/int -> string:
    if str.size <= limit: return str
    return str[..limit]

/**
A tar archiver.

Writes the given files into the writer in tar file format.
*/
class Writer:
  writer_/io.Writer

  /**
  Creates a new tar writer that writes to the given $writer.
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
    header := Header
        --name=file-name
        --permissions=permissions
        --uid=uid
        --gid=gid
        --size=content.byte-size
        --mtime=(mtime or Time.epoch)
        --type=type
        --user-name=user-name
        --group-name=group-name
        --device-major=device-major
        --device-minor=device-minor
    add --header=header content

  /**
  Adds the given $content with the provided $header to the tar archive.

  If the header's name is longer than 100 bytes, the GNU LongLink extension
    is used automatically.
  */
  add --header/Header content/io.Data -> none:
    if header.name.size > Header.NAME-LENGTH_:
      long-link-header := Header
          --name="././@LongLink"
          --permissions=header.permissions
          --uid=header.uid
          --gid=header.gid
          --size=header.name.size
          --mtime=header.mtime
          --type=TYPE-LONG-LINK_
          --user-name=header.user-name
          --group-name=header.group-name
          --device-major=header.device-major
          --device-minor=header.device-minor
      write-entry_ long-link-header header.name
    write-entry_ header content

  /**
  Closes the tar stream, but does not close the writer.
  */
  close:
    // TODO(florian): feels heavy to allocate a new array just to write a bunch of zeros.
    zero-header := ByteArray HEADER-SIZE_
    writer_.write zero-header
    writer_.write zero-header

  /**
  Writes a single header and content block to the tar stream.
  */
  write-entry_ header/Header content/io.Data -> none:
    writer_.write header.to-byte-array
    writer_.write content
    file-size := content.byte-size
    last-chunk-size := file-size % HEADER-SIZE_
    if last-chunk-size != 0:
      missing := HEADER-SIZE_ - last-chunk-size
      writer_.write (ByteArray missing)

/**
A tar reader.

Reads entries from a tar archive provided as an $io.Reader.
*/
class Reader:
  reader_/io.Reader

  /**
  Creates a new tar reader that reads from the given $reader.
  */
  constructor reader/io.Reader:
    reader_ = reader

  /**
  Iterates over all entries in the tar archive.

  Calls the given $block with a $Header and a $ByteArray for each entry.
  LongLink entries are handled transparently: the block is only called for
    actual file entries with their full (long) name.
  */
  do [block]:
    long-name/string? := null
    while true:
      if not reader_.try-ensure-buffered HEADER-SIZE_: return
      header-bytes := reader_.read-bytes HEADER-SIZE_

      // Two consecutive zero blocks signal end of archive.
      if Header.is-zero-block_ header-bytes: return

      header := Header.from-bytes header-bytes --long-name=long-name
      long-name = null

      // Read content (padded to 512-byte boundary).
      content := ByteArray 0
      if header.size > 0:
        reader_.ensure-buffered header.size
        content = reader_.read-bytes header.size
        padding := (HEADER-SIZE_ - (header.size % HEADER-SIZE_)) % HEADER-SIZE_
        if padding > 0: reader_.skip padding

      if header.type == TYPE-LONG-LINK_:
        // LongLink: content is the real filename (may have trailing null).
        end := content.size
        while end > 0 and content[end - 1] == 0: end--
        long-name = content[..end].to-string
        continue

      block.call header content
