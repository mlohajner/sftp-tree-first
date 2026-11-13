## Install with the swap script

The script replaces `/usr/libexec/openssh/sftp-server` and keeps the stock
binary as `sftp-server.orig`. A new `sftp-server` process starts for every
SFTP session, so **no reboot and no `sshd` restart** are needed.

On the machine where you built the binary:

```
sudo ./sftp-server-swap.sh install /path/to/sftp-server
./sftp-server-swap.sh status
sudo ./sftp-server-swap.sh rollback
```

For a **remote server**, the patch has to be on the server (the client is
unchanged). Copy the files over and run the script there:

```
scp sftp-server-swap.sh /path/to/sftp-server user@server:/tmp/
ssh user@server
cd /tmp && sudo ./sftp-server-swap.sh install ./sftp-server
```

The binary must match the server's distribution and library versions. The
script checks this before touching anything: it refuses to install if
`ldd` reports missing libraries or if the binary does not start.

What the script does:

- `install FILE`: smoke-tests the binary, backs up the stock binary to
  `sftp-server.orig` (never overwriting an existing backup), installs the new
  one with mode 755, runs `restorecon`.
- `rollback`: restores `sftp-server.orig`.
- `status`: shows files, SELinux contexts, and whether the stock or the
  patched binary is in place.

If the script is on a `noexec` mount, run it as `bash sftp-server-swap.sh ...`.

Manual equivalent (what the script automates):

```
sudo cp -a /usr/libexec/openssh/sftp-server /usr/libexec/openssh/sftp-server.orig
sudo install -m 755 ./sftp-server /usr/libexec/openssh/sftp-server
sudo restorecon -v /usr/libexec/openssh/sftp-server
ls -Z /usr/libexec/openssh/sftp-server*        # contexts must match
