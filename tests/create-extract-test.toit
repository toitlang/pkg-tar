// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tar
import host.file
import host.directory
import io
import system

import .utils

main:
  test-create-extract-directory
  test-create-extract-single-file
  test-create-extract-nested
  test-create-extract-empty-directory
  test-extract-skips-absolute-paths
  test-extract-skips-path-traversal
  test-roundtrip-preserves-permissions

test-create-extract-directory:
  with-tmp-directory: |tmp|
    source := "$tmp/source"
    directory.mkdir source
    file.write-contents "hello" --path="$source/a.txt"
    file.write-contents "world" --path="$source/b.txt"

    buffer := io.Buffer
    tar.create --writer=buffer --source=source

    target := "$tmp/target"
    directory.mkdir target
    tar.extract --reader=(io.Reader buffer.bytes) --directory=target

    expect-equals "hello" (file.read-contents "$target/a.txt").to-string
    expect-equals "world" (file.read-contents "$target/b.txt").to-string

test-create-extract-single-file:
  with-tmp-directory: |tmp|
    file.write-contents "content" --path="$tmp/single.txt"

    buffer := io.Buffer
    tar.create --writer=buffer --source="$tmp/single.txt"

    target := "$tmp/target"
    directory.mkdir target
    tar.extract --reader=(io.Reader buffer.bytes) --directory=target

    expect-equals "content" (file.read-contents "$target/single.txt").to-string

test-create-extract-nested:
  with-tmp-directory: |tmp|
    source := "$tmp/source"
    directory.mkdir source
    directory.mkdir "$source/sub"
    directory.mkdir "$source/sub/deep"
    file.write-contents "top" --path="$source/top.txt"
    file.write-contents "mid" --path="$source/sub/mid.txt"
    file.write-contents "bottom" --path="$source/sub/deep/bottom.txt"

    buffer := io.Buffer
    tar.create --writer=buffer --source=source

    target := "$tmp/target"
    directory.mkdir target
    tar.extract --reader=(io.Reader buffer.bytes) --directory=target

    expect-equals "top" (file.read-contents "$target/top.txt").to-string
    expect-equals "mid" (file.read-contents "$target/sub/mid.txt").to-string
    expect-equals "bottom" (file.read-contents "$target/sub/deep/bottom.txt").to-string
    expect (file.is-directory "$target/sub")
    expect (file.is-directory "$target/sub/deep")

test-create-extract-empty-directory:
  with-tmp-directory: |tmp|
    source := "$tmp/source"
    directory.mkdir source
    directory.mkdir "$source/empty"
    file.write-contents "data" --path="$source/file.txt"

    buffer := io.Buffer
    tar.create --writer=buffer --source=source

    target := "$tmp/target"
    directory.mkdir target
    tar.extract --reader=(io.Reader buffer.bytes) --directory=target

    expect (file.is-directory "$target/empty")
    expect-equals "data" (file.read-contents "$target/file.txt").to-string

test-extract-skips-absolute-paths:
  buffer := io.Buffer
  tw := tar.Writer buffer
  tw.add "/etc/passwd" "malicious"
  tw.add "safe.txt" "safe"
  tw.close

  with-tmp-directory: |tmp|
    tar.extract --reader=(io.Reader buffer.bytes) --directory=tmp

    expect (file.is-file "$tmp/safe.txt")
    expect-not (file.is-file "$tmp/etc/passwd")

test-extract-skips-path-traversal:
  buffer := io.Buffer
  tw := tar.Writer buffer
  tw.add "../escape.txt" "malicious"
  tw.add "safe.txt" "safe"
  tw.close

  with-tmp-directory: |tmp|
    tar.extract --reader=(io.Reader buffer.bytes) --directory=tmp

    expect (file.is-file "$tmp/safe.txt")
    expect-not (file.is-file "$tmp/../escape.txt")

test-roundtrip-preserves-permissions:
  // On Windows, file.stat returns Windows file attributes, not Unix permissions.
  if system.platform == system.PLATFORM-WINDOWS: return

  with-tmp-directory: |tmp|
    source := "$tmp/source"
    directory.mkdir source
    file.write-contents "executable" --path="$source/run.sh"
    file.chmod "$source/run.sh" 0b111_101_101  // 0755

    buffer := io.Buffer
    tar.create --writer=buffer --source=source

    target := "$tmp/target"
    directory.mkdir target
    tar.extract --reader=(io.Reader buffer.bytes) --directory=target

    stat := file.stat "$target/run.sh"
    expect-equals 0b111_101_101 stat[file.ST-MODE]
