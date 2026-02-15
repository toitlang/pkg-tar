import expect show *
import tar show *
import .utils

main:
  test-properties-verification

test-properties-verification:
  // We use a generator that writes a tar file to the provided writer.
  entries := list-with-tar-bin: |writer|
    tar := TarWriter writer

    // File 1: RW-R--R-- (644).
    tar.add "test-props.txt" "content"
        --permissions=0b110_100_100  // 644.
        --uid=1234
        --gid=5678
        --user-name="testuser"
        --group-name="testgroup"
        --mtime=(Time.epoch + (Duration --s=1000000000))  // 2001-09-09.

    // File 2: OWXRWXRWX (777) but with some mask usually, let's try 755.
    tar.add "executable.sh" "echo hello"
        --permissions=0b111_101_101  // 755.
        --uid=1000
        --gid=1000

    tar.close

  expect-equals 2 entries.size

  // Verify File 1
  entry1 := entries[0]
  expect-equals "test-props.txt" entry1.name
  expect-equals 7 entry1.size
  expect-equals 0b110_100_100 entry1.permissions
  // Note: System tar might display IDs if user/group names don't map to existing users,
  // or it might display the names from the header.
  // The 'utils.toit' listing uses 'tar -tvf' which usually prefers names if available in header (ustar).
  // Let's check what we get. If it fails we might need to adjust expectation to allow IDs.
  // But since we wrote "testuser" in the header, 'tar' should show it.
  expect-equals "testuser" entry1.owner
  expect-equals "testgroup" entry1.group
  // 2001-09-09.
  // Linux: 2001-09-09 03:46 (timezone dependent?).
  // Mac: Sep 9 2001 (or similar).
  // Just check it contains 2001 or Sep.
  print "Entry 1 mtime: $entry1.mtime"
  expect (entry1.mtime.contains "2001")

  // Verify File 2.
  entry2 := entries[1]
  expect-equals "executable.sh" entry2.name
  expect-equals 10 entry2.size
  expect-equals 0b111_101_101 entry2.permissions
  expect-equals "1000" entry2.owner
  expect-equals "1000" entry2.group
