#!/bin/sh
# Install ucsi-ite as a DKMS module and load it.
set -eu

cd "$(dirname "$0")"
NAME=ucsi-ite
VER=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' src/dkms.conf)

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

# Drop any other installed version first; they share the module name.
for old in $(dkms status "$NAME" 2>/dev/null | sed -n "s|^$NAME/\([^,:]*\).*|\1|p" | sort -u); do
	[ "$old" = "$VER" ] && continue
	echo "Removing $NAME/$old"
	dkms remove "$NAME/$old" --all
	rm -rf "/usr/src/$NAME-$old"
done

rm -rf "/usr/src/$NAME-$VER"
cp -r src "/usr/src/$NAME-$VER"
dkms add "$NAME/$VER" 2>/dev/null || true
dkms install "$NAME/$VER"

modprobe -r ucsi_ite 2>/dev/null || true
modprobe ucsi_ite

# Ports register asynchronously after probe.
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ -n "$(ls /sys/class/typec/ 2>/dev/null)" ] && break
	sleep 1
done
echo
ls /sys/class/typec/ 2>/dev/null | grep . || echo "No /sys/class/typec entries (no ITE885x controller bound?)"
