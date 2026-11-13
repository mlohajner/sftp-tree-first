# 🌳 "Tree first" patch for SFTP

OpenSSH's `sftp-server` returns directory entries in whatever order the
filesystem hands them out. On a large directory over a slow or high-latency
link (VPN, hotspot, congested Wi-Fi), a client that displays entries as they
arrive (e.g. Nemo/GVfs) shows a few folders, waits for a long stream of files,
shows a few more folders, and only settles once the whole listing is in.

This patch makes the **server** send entries in two passes:

1. everything that is not a regular file (directories, all symlinks, other
   types),
2. regular files.

The SFTP protocol does not define an order for `READDIR`, so the protocol and
all clients stay unchanged. The client simply sees the complete folder tree
first and the files stream in afterwards. Stopping the listing early
(closing the handle) still works as before.

Files in this package:

| File | Purpose |
|---|---|
| `1001-sftp-server-directory-first.patch` | the patch (9 added lines, 0 removed, in `sftp-server.c`) |
| `sftp-server-swap.sh` | installs the patched binary with a backup, and rolls back |

Written against the Fedora 44 source of OpenSSH 10.2p1 (release 16); it applies
with `patch --fuzz=0`. Other distributions will need their own source and
build steps, but the patch itself only touches `process_readdir()` in
`sftp-server.c`.

## How it works

- `process_readdir()` skips entries by type: in the first pass it skips
  regular files (`d_type == DT_REG`), in the second pass it skips everything
  else. The test runs right after `readdir()`, before any `lstat()`, so
  skipped entries cost almost nothing.
- When the first pass reaches the end of the directory, the handle switches to
  the second pass, calls `rewinddir()` and continues. `SSH_FX_EOF` is sent only
  after the second pass.
- The pass is stored per directory handle in `Handle.flags`, which is
  otherwise only used for open files. `READDIR` is called once per packet
  (100 entries), so the state cannot be a local variable.
- Entries stream out as before: a packet is sent after 100 entries, nothing is
  buffered. The first packet leaves once 100 non-regular entries are found or
  the first pass ends, whichever comes first.
- Symlinks are never resolved. All of them (to files or directories, even
  dangling ones) go out with the first group.
- Order is guaranteed in the stream, not per packet: the packet at the
  transition can contain both groups, non-regular entries first.
- On a filesystem that reports `DT_UNKNOWN`, every entry counts as "not a
  regular file", so everything is sent in the first pass: same behavior as
  stock, nothing lost or duplicated.
