#!/bin/bash
# Swap /usr/libexec/openssh/sftp-server with a patched build, with rollback.
#
#   sudo ./sftp-server-swap.sh install /path/to/patched/sftp-server
#   sudo ./sftp-server-swap.sh rollback
#   ./sftp-server-swap.sh status
set -euo pipefail

TARGET=/usr/libexec/openssh/sftp-server
ORIG=$TARGET.orig

die() { echo "ERROR: $*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "run as root (sudo)"; }

case "${1:-}" in
install)
	need_root
	NEW=${2:-}
	[ -f "$NEW" ] || die "usage: $0 install /path/to/patched/sftp-server"

	# Smoke test: binary must load all libraries and start
	if ldd "$NEW" | grep -q "not found"; then
		ldd "$NEW" | grep "not found" >&2
		die "missing libraries; build on the same distro/version as this server"
	fi
	# -Z prints usage and exits non-zero by design, so capture output first
	out=$("$NEW" -Z 2>&1 || true)
	grep -q '^usage:' <<<"$out" || die "new binary does not start correctly: $out"

	# Keep the stock binary, but never overwrite an existing backup
	if [ -e "$ORIG" ]; then
		echo "keeping existing backup $ORIG"
	else
		cp -a "$TARGET" "$ORIG"
		echo "backed up stock binary to $ORIG"
	fi

	install -m 755 "$NEW" "$TARGET"
	restorecon -v "$TARGET" 2>/dev/null || true
	echo "installed. Reconnect SFTP clients (old sessions keep the old process)."
	;;
rollback)
	need_root
	[ -e "$ORIG" ] || die "no backup at $ORIG (try: dnf reinstall openssh-server)"
	install -m 755 "$ORIG" "$TARGET"
	restorecon -v "$TARGET" 2>/dev/null || true
	echo "restored stock binary."
	;;
status)
	ls -lZ "$TARGET" "$ORIG" 2>&1 || true
	if [ -e "$ORIG" ] && cmp -s "$TARGET" "$ORIG"; then
		echo "-> STOCK binary is in place"
	elif [ -e "$ORIG" ]; then
		echo "-> PATCHED binary is in place"
	else
		echo "-> no backup yet (stock, or never swapped)"
	fi
	;;
*)
	sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
	;;
esac
