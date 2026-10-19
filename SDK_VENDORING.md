# Vendoring and Pruning the Bouffalo SDK

This document describes how `third_party/bouffalo_sdk` in this repository was produced, how to
update it, and how to apply the same approach to the XInput (Xbox 360) firmware.

The short version: the SDK is a **normal tracked directory**, not a submodule. It is a patched,
conservatively pruned copy of the full Bouffalo SDK. A fresh clone builds without an external SDK
checkout; the toolchain is downloaded separately.

## 1. Goal and constraints

- **Clone and build**: `git clone` + `./build.sh` must work without cloning the SDK separately.
- **Patched SDK**: the firmware depends on local USB/BT fixes; see [SDK_CHANGES.md](SDK_CHANGES.md).
- **Reproducible**: the exact SDK state is part of the app repository's history.
- **Small enough**: the app repo pack is ~122.5 MiB; the SDK working tree is ~410 MB.
- **Licensed**: keep the SDK's Apache-2.0 `LICENSE` and the app's `NOTICE`.

The trade-off is repo size. The current vendor is deliberately conservative: it removes material
that the build never reads (examples, docs, VCS history, most tools) but keeps all components,
drivers and BSP files. A deeper prune is possible, but it is a separate test-driven exercise.

## 2. Current numbers

| Metric | Full upstream SDK | Vendored copy |
|---|---:|---:|
| Working tree | ~1.6 GB | ~410 MB |
| `.git/` | 455 MB | removed |
| `examples/` | 342 MB | removed |
| `docs/` | 11 MB | removed |
| `tools/` | 384 MB | 39 MB |
| `components/` | ~318 MB | ~320 MB |
| `drivers/` | 35 MB | 35 MB |
| `bsp/` | 15 MB | 15 MB |
| Files | 17,201 on disk (17,121 tracked) | 11,782 on disk (11,639 tracked) |
| Tracked content (git tree) | — | ~376.6 MiB |
| App repo pack | — | ~122.5 MiB |

`du -sh` on the working tree is not the distributed size. The app repository stores the SDK
compressed; a clone is ~123 MiB packed, then checks out to ~410 MB.

## 3. What the vendor keeps

| Path | Size | Why |
|---|---:|---|
| `CMakeLists.txt`, `project.build`, `board.build`, `cmake/`, `Kconfig`, `VERSION` | small | The SDK build system; `project.build` is included by the app's `Makefile`. |
| `bsp/` | 15 MB | Board definitions, linker scripts, boot2/partition configs. All boards are kept. |
| `drivers/` | 35 MB | HAL/SoC drivers. All SoCs are kept. |
| `components/` | ~320 MB | BT stack, CherryUSB, FreeRTOS, libc, crypto, partition utils, etc. Kept wholesale. |
| `tools/bflb_tools/bflb_fw_post_proc/` | 29 MB | Required to turn the ELF into the flashable `.bin`. |
| Small dev tools (`genromfs`, `genlfs`, `lpfw`, `byai`, `footprint`, gdb scripts) | ~10 MB | Not required by this app; kept for now, removable in a stricter prune. |
| `.github/`, `.claude/`, `.cproject`, `.project`, `.clang-format`, `.gitignore` | small | Current vendor keeps some developer metadata; optional. |

The dominant cost is the prebuilt wireless/crypto libraries under `components/`. The Bluetooth
stack alone is ~41 MB, and the whole `components/wireless` tree is ~160 MB.

## 4. What the vendor removes

| Path | Size | Reason |
|---|---:|---|
| `.git/` | 455 MB | The app repo has its own history; a nested repo doubles the size and complicates `git add`. |
| `examples/` | 342 MB | Not used to build this app. |
| `docs/` | 11 MB | Upstream documentation; link to upstream instead. |
| `tools/bflb_tools/bouffalo_flash_cube/` | 250 MB | GUI/CLI flashing tools. **Trade-off**: `./build.sh flash` needs `BLFlashCommand` copied from the full SDK; see [FLASHING.md](FLASHING.md). |
| `tools/bflb_tools/bouffalo_mfg_tool/` | 37 MB | Manufacturing tool; not used by this app. |
| `tools/cmake/`, `tools/make/`, `tools/ninja/` | ~34 MB | The build uses the system `cmake` and GNU Make (>= 4.0). |
| `tools/openocd/`, `tools/cklink_firmware/` | ~26 MB | Debugger tooling; not needed to build or flash over UART. |

Removed material totals roughly 1.15 GB including `.git`; the vendored tree is ~410 MB.

## 5. Reproducible prune procedure

Start from a **patched** full SDK at the recorded commit (see section 6), not from an arbitrary
upstream checkout.

```bash
SRC=/path/to/patched/bouffalo_sdk
DST=/path/to/app/third_party/bouffalo_sdk

# 1. Copy the patched tree (destination is only the SDK directory).
mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"

# 2. Remove content the app build does not read.
rm -rf "$DST/.git" \
       "$DST/examples" \
       "$DST/docs" \
       "$DST/tools/bflb_tools/bouffalo_flash_cube" \
       "$DST/tools/bflb_tools/bouffalo_mfg_tool" \
       "$DST/tools/cmake" \
       "$DST/tools/make" \
       "$DST/tools/ninja" \
       "$DST/tools/openocd" \
       "$DST/tools/cklink_firmware"

# 3. Optional stricter prune (developer metadata, not required by the build):
# rm -rf "$DST/.github" "$DST/.claude" "$DST/.cproject" "$DST/.project" \
#        "$DST/.clang-format" "$DST/BouffaloSDK.png" \
#        "$DST/bouffalo_sdk.code-workspace" "$DST/CLAUDE.md"

# 4. Check what remains.
du -sh "$DST"
find "$DST" -type f | wc -l
find "$DST" -type l            # should be empty; fix broken symlinks if not
```

Do **not** run `rsync --delete` against the app repository root; it would delete the app. Only
sync into the SDK directory.

After copying, verify the build (section 8) before committing. Keep `LICENSE`, `project.build`,
`cmake/`, `Kconfig`, `bsp/`, `drivers/`, `components/`, and
`tools/bflb_tools/bflb_fw_post_proc/`.

## 6. Patches: what is not upstream

The current fork is based on upstream `42c20811` with local commit `ec8c6e9d`
(`feat(usb,bt): P0 audio session hardening, F0 guard rework, BT TX ownership`, 15 files,
+2028/−91). [SDK_CHANGES.md](SDK_CHANGES.md) documents each change, the original problem, and the
consequence of using the unpatched SDK.

Practices that keep this maintainable:

1. Keep the patches as **commits in a full SDK checkout**, not as ad-hoc edits in the vendored copy.
2. Export a patch series (`git format-patch 42c20811..ec8c6e9d`) or keep the full SDK commit
   accessible. The vendored copy alone cannot be rebased.
3. When updating upstream: rebase the local commits, resolve conflicts, re-run the prune, then
   rebuild every board and variant.
4. Update `SDK_CHANGES.md` with the new base and local commit.
5. Keep app-side code (USB descriptors, XUSB mapping, DS4 HID descriptor) in the app repo, not in
   the SDK. Only put changes in the SDK when they belong to the shared stack.
6. Consider adding `third_party/bouffalo_sdk/VENDORED_SDK_COMMIT` with the upstream and local
   hashes; it makes the vendor state explicit.

The P0 fixes are mostly generic USB device-controller/CherryUSB/BT-host hardening. The XInput
persona uses the same stack, so it should start from the same patched SDK unless a specific patch
is proven DS4-only.

## 7. Build integration

- `build.sh` exports `BL_SDK_BASE="${SCRIPT_DIR}/third_party/bouffalo_sdk"`.
- `CMakeLists.txt` uses `find_package(bouffalo_sdk REQUIRED HINTS $ENV{BL_SDK_BASE})`.
- `Makefile` includes `$(BL_SDK_BASE)/project.build`.
- The toolchain is **not** vendored: `setup_toolchain.sh` downloads the official Xuantie
  toolchain into `third_party/toolchain/` (git-ignored). The SDK needs
  `-march=rv32imafcpzpsfoperand_xtheade`; distro GCC cannot compile it.
- `.gitignore` excludes `/build/`, `/firmware/`, `/misc/`, `/release/` and
  `/third_party/toolchain/`.

## 8. Validation checklist

Run from a **fresh clone**, not only the working tree:

```bash
git clone <app-repo> /tmp/app-check
cd /tmp/app-check
./build.sh                     # default board/variant
AUDIO=0 ./build.sh             # gamepad-only build
SPEAKER=1 ./build.sh           # speaker routing (DS4 only)
./release.sh                   # release bundle
git status --short             # must be clean: no build outputs tracked
```

Also check:

```bash
git ls-files third_party/bouffalo_sdk | wc -l
git ls-tree -r -l HEAD third_party/bouffalo_sdk | awk '{sum+=$4} END {printf "%.1f MiB\n", sum/1048576}'
git check-ignore -v third_party/bouffalo_sdk/components/wireless/macsw/lib/libmacsw_bl616.a
```

The last command must print nothing (the file must be tracked). A fresh-clone build is the real
test: it proves no needed file was left behind as ignored/untracked.

## 9. Gotchas

### 9.1 The SDK's own `.gitignore`

The vendored SDK includes its own `.gitignore`. When you `git add third_party/bouffalo_sdk`, Git
applies it, so some files present on disk are **not** tracked. In this repository 143 files are in
that state (e.g. `bouffalo_sdk.code-workspace`, `.clangd`, some third-party build-info headers and
CMake files). The BL616 build is verified from the tracked vendor, so this configuration does not need
them. For a new app, make the fresh-clone build the gate.

For a new app, verify the fresh-clone build. If a needed file was skipped, either `git add -f` that
specific file or adjust/remove the SDK `.gitignore`. Do not blindly force-add hundreds of ignored
build artifacts.

### 9.2 A global `*.a` / `*.bin` ignore will hide the SDK

This is the biggest trap when copying the vendor into a new repository. An app `.gitignore` like:

```gitignore
*.a
*.bin
```

will silently hide the SDK's prebuilt Bluetooth/USB libraries and boot2/partition images. The build
works locally, then fails on a fresh clone. Before adding the SDK, check:

```bash
git check-ignore -v third_party/bouffalo_sdk/components/wireless/macsw/lib/libmacsw_bl616.a
git check-ignore -v third_party/bouffalo_sdk/bsp/board/bl616dk/config/boot2_bl616_isp_release_v8.1.8.bin
```

Both must be **not ignored**. Prefer path-scoped ignores (`/build/**/*.a`, `/lib/*.a`) over a
global `*.a`; the same applies to `*.bin`.

### 9.3 Other pitfalls

- **Flash tool removed**: `bouffalo_flash_cube` is gone; use Dev Cube or copy `BLFlashCommand`
  from the full SDK. `build.sh flash` will error if the binary is missing.
- **Toolchain not tracked**: `third_party/toolchain/` is ~700 MB extracted; never commit it.
- **Absolute paths**: do not vendor a tree that was configured/built elsewhere; use a clean copy.
  Build caches contain absolute paths and are not part of the vendor.
- **Symlinks**: upstream may contain symlinks; check `find -type l` after pruning.
- **License**: keep the SDK's Apache-2.0 `LICENSE`; keep the app's `NOTICE` and GPL-3.0 `LICENSE`.
- **Kconfig/CMake references**: removing a component can break configure or the link step even if
  the app never calls it. Test after each removal.
- **Keep `bflb_fw_post_proc`**: without it the `.bin` generation fails, even though compilation
  succeeds.

## 10. Optional deeper prune

The current vendor keeps all components/drivers/BSP. If you need a smaller tree, prune in small,
tested steps. Candidate savings and risks:

| Candidate | Approx. saving | Risk |
|---|---:|---|
| `bsp/board/*` except `bl616dk` | ~4 MB | Board/Kconfig/linker references; the build uses `BOARD=bl616dk`. |
| `drivers/soc/*` except `bl616` | ~20 MB | Chip selection/CMake; the build uses `CHIP=bl616`. |
| `components/wireless/wifi6`, `wl80211`, `thread`, `wifi4`, `bl_wpa_supplicant` | ~100 MB | BT may still reference `macsw`/`coex`/`lpfw_private`; check the link map. |
| `components/wireless/macsw` | ~30 MB | The BT controller/macsw library may depend on it. Test. |
| `components/graphics` | ~42 MB | Not used by this app, but Kconfig may reference it. |
| `components/crypto` | ~73 MB | BT SSP/AES may need it. Do not remove blindly. |
| `components/net`, `multimedia`, `fs`, `ipc` | ~35 MB | May be referenced by Kconfig/other components. |
| Small dev tools under `tools/` (except `bflb_fw_post_proc`) | ~10 MB | None for this build. |
| `.github`, `.claude`, IDE files | <1 MB | None. |

A realistic deep prune could reach ~150–250 MB, but the prebuilt wireless/crypto libs dominate and
the link dependencies are not obvious. **Recommendation: do not combine deep pruning with protocol
work.** Start with the current 410 MB vendor, get the XInput firmware working, then remove one
group at a time with a full build + fresh-clone test after each step.

## 11. Applying this to the XInput repository

The XInput repo (`ds4x360-bl616`) currently builds against a sibling `../bouffalo_sdk`. To adopt
the vendored model:

1. Copy the SDK (the patched, conservative vendor):

   ```bash
   mkdir -p third_party
   rsync -a /path/to/ds4dongle-bl618/third_party/bouffalo_sdk/ \
             third_party/bouffalo_sdk/
   ```

2. **Fix `.gitignore` before `git add`**. The XInput repo currently has global `*.a` and `*.bin`
   rules. Scope or remove them, and add the toolchain ignore:

   ```gitignore
   /build/
   /firmware/
   /release/
   /third_party/toolchain/

   # Do not use global *.a / *.bin here: they would hide the vendored SDK's
   # prebuilt libraries and boot2/partition images.
   ```

   Then verify:

   ```bash
   git check-ignore -v third_party/bouffalo_sdk/components/wireless/macsw/lib/libmacsw_bl616.a
   git check-ignore -v third_party/bouffalo_sdk/bsp/board/bl616dk/config/boot2_bl616_isp_release_v8.1.8.bin
   ```

3. Update the SDK path defaults:

   - `build_macos.sh`: `BL_SDK_BASE="${SCRIPT_DIR}/third_party/bouffalo_sdk"`
   - `Makefile`: `BL_SDK_BASE ?= $(abspath third_party/bouffalo_sdk)`
   - `build_windows.bat`: `set "BL_SDK_BASE=%~dp0third_party\bouffalo_sdk"`
   - `CMakeLists.txt` already uses `$ENV{BL_SDK_BASE}`; no change needed.
   - Update `README.md` / `README_CN.md` build instructions that currently say `../bouffalo_sdk`.

4. Add the toolchain downloader (`setup_toolchain.sh`) and the `/third_party/toolchain/` ignore.

5. Stage and verify the vendor:

   ```bash
   git add third_party/bouffalo_sdk
   git ls-files third_party/bouffalo_sdk | wc -l          # ~11639
   git ls-tree -r -l HEAD third_party/bouffalo_sdk | \
     awk '{sum+=$4} END {printf "%.1f MiB\n", sum/1048576}'   # ~376.6
   ```

6. Build both XInput variants:

   ```bash
   XINPUT=1 ./build_macos.sh
   XINPUT=1 AUDIO=0 ./build_macos.sh
   ```

7. Fresh-clone test: clone the XInput repo to `/tmp`, build there, and confirm no missing
   libraries or boot2 images.

8. Commit the vendor and path changes separately from protocol work. Add an XInput
   `SDK_CHANGES.md` (copy/adapt this repo's file) recording `42c20811` and `ec8c6e9d`, plus any
   XInput-specific SDK patch.

9. Keep `build/`, `firmware/`, `release/` and `third_party/toolchain/` out of Git.

The XUSB descriptors, MS OS 1.0 extended properties and XInput mapping belong in the app repo, not
in the SDK. Only add an SDK patch if the shared USB/BT stack itself needs a change; document it in
the XInput `SDK_CHANGES.md`.

## 12. Final checklist

- [ ] SDK copied from a **patched** checkout at the recorded commit.
- [ ] `.git`, `examples`, `docs` and the unused tools removed.
- [ ] `tools/bflb_tools/bflb_fw_post_proc` kept.
- [ ] `LICENSE`, `NOTICE` present.
- [ ] No global `*.a` / `*.bin` ignore hides the SDK.
- [ ] `git ls-files third_party/bouffalo_sdk | wc -l` matches expectations.
- [ ] No `.git`, no build outputs, no toolchain inside the vendor.
- [ ] Fresh clone builds every supported board/variant.
- [ ] Flash path documented (Dev Cube or copied `BLFlashCommand`).
- [ ] `SDK_CHANGES.md` / `VENDORED_SDK_COMMIT` updated.
