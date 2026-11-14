# Denial mobile on shennong / Droidian

This is the optional native Denial session for the existing slot B Droidian
installation. It does not flash partitions, alter slot A, replace the kernel,
or replace Droidian's USB, radio, Wi-Fi, audio or Bluetooth services.

## Graphics boundary

Denial uses DRM/KMS directly and the private KGSL Mesa build under
`/opt/denial-shennong/mesa`. The environment applies to this session only;
the system EGL/GBM libraries and stock Android Composer remain unchanged.
Android HWC and Phosh must stop before Denial takes the display.

The KGSL allocator's GBM handles are not the downstream display driver's GEM
handles, even when GBM was initialized with the same DRM fd. The opt-in
`DENIAL_IMPORT_GBM_SCANOUT=1` uses Denial's existing DMA-BUF PRIME import path
for scanout. Without it, native ADDFB2 and legacy ADDFB return ENXIO. The on-device
probe registered the same buffer successfully after PRIME import.

The native output configuration selects the 1440x3200 DSI panel at 60 Hz,
scale 3, and disables Qualcomm's two virtual writeback connectors. Output
changes made in Denial Settings remain in Denial's own writable user state.
The native `DENIAL_SHELL_PROFILE=mobile` selects its phone interface. Chinese
locale and Asia/Shanghai timezone are inherited from Droidian.

## Reproduction

`inputs.lock.json` pins the upstream ARM64 0.6.3 bundle, its matching custom
Flutter engine, the release signing key and KGSL Mesa. The engine matches this
fork's `prebuilt/flutter-engine/SOURCE_LOCK.json`; it is not a stock Flutter
engine. The local compositor is built from this fork, with the opt-in scanout
adaptation. The wire schema and engine lock match the release bundle.

The stock touch firmware is explicitly handed from its Android raw-frame
path to standard evdev coordinates after Android Composer stops. A small
native session initializer resumes the existing controller and selects that
standard mode once; it does not read, synthesize or proxy touch events.

On this downstream SDE driver, generic plane clear also fails because
Smithay resets alpha to 65535 while the exposed maximum is 255. The adapter
detaches the owned plane, connector and CRTC without resetting unrelated
plane properties, and synchronizes Smithay's state for the next wake frame.
The user has confirmed both screen power toggling and touch after these fixes.

`DENIAL_SDE_RELEASE_FENCE=1` requests the driver's 64-bit `output_fence`
descriptor and waits for its PP_DONE release in the submission worker before
announcing the commit as submitted. The timeout is bounded at 250 ms; failures
remain visible. This adds the driver's native release boundary before an old
buffer can become reusable. The user retested this candidate: horizontal
tearing remained essentially unchanged, so this is not a fix for that symptom.
The driver reports completed release/retire timelines with zero underruns;
panel triggering/TE configuration remains under investigation.

On the native ARM64 Linux builder with the repository's Rust 1.98.0 toolchain
and libseat/libinput/libudev/libdrm/GBM/Wayland/xkbcommon development packages:

```sh
python3 devices/shennong/tools/verify-inputs.py local-build/inputs --download
devices/shennong/tools/build-native.sh
devices/shennong/tools/package-native.sh local-build/inputs local-build/native local-build/packages
sudo devices/shennong/tools/install-runtime.sh /PATH/TO/DROIDIAN_ROOT \
  local-build/inputs local-build/packages/denial_0.6.3-1+shennong2_arm64.deb
```

Use `/` as the target only on the phone itself. The installer only installs;
it neither starts a desktop nor changes the boot selection. Select the native
`denial-shennong.service` after successful live activation. No boot-time
configuration writer, watchdog or automatic fallback is added.

Current validation: native GBM and surfaceless EGL use FD750 / GLES 3.2;
PRIME-imported display buffers register successfully; Denial mobile renders
through Impeller; Xwayland starts with the session's private Mesa environment.
Touch and panel power/wake are confirmed. Horizontal tearing, cold-start
persistence and sustained rendering still require validation before this
session becomes the boot default. The original Phosh packages stay installed.
