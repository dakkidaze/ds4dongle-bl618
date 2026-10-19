#!/usr/bin/env bash
# Build the three release variants and assemble a flashable bundle in release/.
#
#   wired         ./build.sh            USB audio -> headset jack only; the
#                                       built-in speaker stays silent with no
#                                       headset (matches a wired DS4)
#   gamepadonly   AUDIO=0 ./build.sh    no UAC1 audio function
#   speaker       SPEAKER=1 ./build.sh  no headset -> L+R downmix to the
#                                       built-in speaker
#
# The boot2/partition payload is identical for all three variants; only the
# application image and the per-variant flash_prog_cfg-*.ini differ.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BOARD_TYPE="${BOARD_TYPE:-lctech616}"
if [[ "$BOARD_TYPE" != "lctech616" ]]; then
    echo "ERROR: release assets are defined for lctech616 only (BOARD_TYPE=${BOARD_TYPE})." >&2
    echo "       Unset BOARD_TYPE or set BOARD_TYPE=lctech616." >&2
    exit 1
fi

OUT_DIR="firmware/${BOARD_TYPE}"
REL_DIR="release"

rm -rf "$REL_DIR"
mkdir -p "$REL_DIR"

# Track the boot2 image name (same file for every variant, but read it from the
# build output so a version bump does not silently break the flash configs).
BOOT2_NAME=""

require_file() {
    if [[ ! -f "$1" ]]; then
        echo "ERROR: expected build output missing: $1" >&2
        exit 1
    fi
}

# Copy boot2 + partition into release/ (idempotent, identical for all variants).
copy_common() {
    local boot2_files=()
    shopt -s nullglob
    boot2_files=("${OUT_DIR}"/boot2_*.bin)
    shopt -u nullglob

    if [[ ${#boot2_files[@]} -ne 1 ]]; then
        echo "ERROR: expected exactly one ${OUT_DIR}/boot2_*.bin, found ${#boot2_files[@]}." >&2
        exit 1
    fi
    BOOT2_NAME="$(basename "${boot2_files[0]}")"
    cp -f "${boot2_files[0]}" "${REL_DIR}/${BOOT2_NAME}"
    require_file "${OUT_DIR}/partition.bin"
    cp -f "${OUT_DIR}/partition.bin" "${REL_DIR}/partition.bin"
}

# build_variant <variant> <source bin> [env assignments...]
build_variant() {
    local variant="$1"
    local src="$2"
    shift 2

    echo ""
    echo "============================================================"
    echo "[release] Building ${variant}"
    echo "============================================================"
    env "$@" ./build.sh

    require_file "$src"
    cp -f "$src" "${REL_DIR}/ds4dongle-bl618-${variant}.bin"
    copy_common

    cat > "${REL_DIR}/flash_prog_cfg-${variant}.ini" <<FLASH_CFG
[cfg]
erase = 1
skip_mode = 0x0, 0x0
boot2_isp_mode = 0

[boot2]
filedir = ./${BOOT2_NAME}
address = 0x000000

[partition]
filedir = ./partition.bin
address = 0xE000

[FW]
filedir = ./ds4dongle-bl618-${variant}.bin
address = @partition
FLASH_CFG

    echo "[release] ${variant} -> ${REL_DIR}/ds4dongle-bl618-${variant}.bin"
}

echo "[release] Board: ${BOARD_TYPE} (LCTech BL616)"

build_variant wired \
    "${OUT_DIR}/ds4dongle-lctech616.bin"
build_variant gamepadonly \
    "${OUT_DIR}/ds4dongle-lctech616-noaudio.bin" \
    AUDIO=0
build_variant speaker \
    "${OUT_DIR}/ds4dongle-lctech616-spk.bin" \
    SPEAKER=1

cat > "${REL_DIR}/README.txt" <<'README_TXT'
DS4Dongle BL618 - release bundle (LCTech BL616)
===============================================

Variants
--------
wired         ds4dongle-bl618-wired.bin
              Default build (./build.sh). Matches a wired DS4: USB audio goes
              to the headset jack only. With no headset plugged, the built-in
              speaker stays silent (audio blocks are dropped while the USB
              stream keeps pacing the host).

gamepadonly   ds4dongle-bl618-gamepadonly.bin
              Built with AUDIO=0. No UAC1 audio function; gamepad only.

speaker       ds4dongle-bl618-speaker.bin
              Built with SPEAKER=1 (custom). With no headset, the stereo
              stream is downmixed L+R to the controller's built-in mono
              speaker. A plugged headset still receives stereo.

Each variant ships with its own flash configuration:
  flash_prog_cfg-wired.ini
  flash_prog_cfg-gamepadonly.ini
  flash_prog_cfg-speaker.ini
boot2_*.bin and partition.bin are identical for all variants.

What the .ini does
------------------
The .ini is a flash layout manifest, not firmware. It tells the flashing tool:
  boot2     -> 0x000000
  partition -> 0xE000
  app       -> @partition (resolved from partition.bin; 0x10000 on this layout)
Keep the files together: the ini uses relative paths. If you rename a bin,
edit the matching [FW] filedir line.

Full guide: https://github.com/dakkidaze/ds4dongle-bl618/blob/main/FLASHING.md

Flashing with Bouffalo Dev Cube
-------------------------------
1. Put the board into ISP mode: unplug it, hold BOOT, plug it back in.
2. Start Bouffalo Dev Cube, select chip BL616 and the UART interface, then
   pick the serial port.
3. Load flash_prog_cfg-<variant>.ini and click Download/Flash.
4. Keep all files together in this directory: the .ini references the boot2,
   partition and firmware files by relative path.

Hardware validation: LCTech BL616 only. The wired and speaker routing
variants are build-verified; the wired no-headset-silent behaviour is new and
has not been re-validated on hardware yet. Other boards build but are
untested.
README_TXT

echo ""
echo "[release] Contents:"
ls -lh release

echo ""
echo "[release] SHA-256:"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum release/*.bin
else
    shasum -a 256 release/*.bin
fi

echo ""
echo "[release] Done: three variants in ${REL_DIR}/"
