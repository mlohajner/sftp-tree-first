# Prebuilt SFTP binary

Inluded here is a prebuilt `sftp-server` with the tree first patch applied: directories and
symlinks are sent before regular files, so file managers show the folder tree
first.

- Fedora: 44
- OpenSSH: 10.2p1

## Install

If you trust this prebuilt binary, you can install it directly using the
provided `sftp-server-swap.sh` script:

```
sudo ./sftp-server-swap.sh install ./sftp-server
```

The script keeps the stock binary as `sftp-server.orig` and installs this one
in its place. Reconnect your SFTP clients afterwards.

## Check or roll back

```
./sftp-server-swap.sh status
sudo ./sftp-server-swap.sh rollback
```
