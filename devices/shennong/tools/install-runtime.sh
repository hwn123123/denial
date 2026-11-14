#!/usr/bin/env bash
# Offline-root or live-device installation. This is not a boot-time service.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
[[ $EUID == 0 && $# == 3 ]] || {
    echo "usage: sudo $0 DEVICE_ROOT VERIFIED_INPUT_DIR SHENNONG_DEB" >&2
    exit 2
}
root=$(realpath "$1")
inputs=$(realpath "$2")
package=$(realpath "$3")
grep -qx 'device=shennong' "$root/etc/droidian/shennong-build"
[[ $(dpkg-deb -f "$package" Package) == denial ]]
[[ $(dpkg-deb -f "$package" Version) == 0.6.3-1+shennong2 ]]
[[ $(dpkg-deb -f "$package" Architecture) == arm64 ]]
python3 "$here/verify-inputs.py" "$inputs"
if [[ $root == / ]]; then
    # Do not replace libraries or binaries mapped by a running Denial session.
    systemctl stop denial-shennong.service
fi
cache="$root/var/cache/denial-shennong-install"
mkdir -p "$cache"
trap 'rm -rf -- "$cache"' EXIT
install -m644 "$package" "$cache/denial-shennong.deb"
install -m644 "$inputs/denial-flutter-engine_0.6.3-1_arm64.deb" "$cache/engine.deb"
chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libllvm21 /var/cache/denial-shennong-install/engine.deb /var/cache/denial-shennong-install/denial-shennong.deb
mkdir -p "$root/opt/denial-shennong/mesa"
tar -xzf "$inputs/mesa-for-android-container_27.0.0-devel-20261025-r2_debian_testing_arm64.tar.gz" \
    -C "$root/opt/denial-shennong/mesa" --no-same-owner
install -D -m644 "$here/../inputs.lock.json" "$root/usr/share/doc/denial-shennong/inputs.lock.json"
# Selection is deliberate, after live startup succeeds; no automatic rollback.
echo 'Installed. Activate with systemctl start denial-shennong.service.'
echo 'After validation, disable phosh and android-service@hwcomposer; enable denial-shennong.'
