#!/usr/bin/env bash
# Produce a versioned Debian package without overwriting an active compositor.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo=$(cd -- "$here/../../.." && pwd -P)
[[ $# == 3 ]] || { echo "usage: $0 VERIFIED_INPUT_DIR NATIVE_BUILD_DIR OUTPUT_DIR" >&2; exit 2; }
inputs=$(realpath "$1")
build=$(realpath "$2")
mkdir -p "$3"
output=$(realpath "$3")
python3 "$here/verify-inputs.py" "$inputs"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
dpkg-deb -R "$inputs/denial_0.6.3-1_arm64.deb" "$work/package"
install -m755 "$build/release/deniald" "$work/package/usr/bin/deniald"
install -m755 "$build/release/denialctl" "$work/package/usr/bin/denialctl"
install -D -m755 "$build/release/denial-shennong-touch" "$work/package/usr/libexec/denial-shennong-touch"
sed -i 's/^Version: .*/Version: 0.6.3-1+shennong2/' "$work/package/DEBIAN/control"
cp -a "$here/../rootfs/." "$work/package/"
mkdir -p "$work/package/usr/share/doc/denial-shennong"
cp "$here/../inputs.lock.json" "$work/package/usr/share/doc/denial-shennong/"
git -C "$repo" rev-parse HEAD > "$work/package/usr/share/doc/denial-shennong/source-commit"
git -C "$repo" diff --binary HEAD > "$work/package/usr/share/doc/denial-shennong/source-changes.patch"
(cd "$work/package" && find usr etc -type f -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums)
dpkg-deb --root-owner-group --build "$work/package" "$output/denial_0.6.3-1+shennong2_arm64.deb"
