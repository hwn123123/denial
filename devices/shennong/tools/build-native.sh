#!/usr/bin/env bash
# Build just the compositor/control client, reusing the pinned ARM64 engine.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo=$(cd -- "$here/../../.." && pwd -P)
[[ $(uname -sm) == 'Linux aarch64' ]] || {
    echo 'Run on the ARM64 Linux builder with native development dependencies.' >&2
    exit 2
}
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$repo/local-build/native}"
jobs=${SHENNONG_BUILD_JOBS:-$(( $(nproc) > 4 ? $(nproc) - 4 : 1 ))}
cd "$repo/compositor"
cargo build --locked --release --jobs "$jobs" --features flutter --bin deniald --bin denialctl
cc -O2 -Wall -Wextra -Werror "$here/../compat/touch-handoff.c" \
    -o "$CARGO_TARGET_DIR/release/denial-shennong-touch"
