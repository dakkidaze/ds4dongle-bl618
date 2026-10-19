# DS4Dongle BL618

[中文文档 (Chinese)](README_CN.md) · [Build guide](BUILD.md)

A wireless **DualShock 4 (CUH-ZCT2)** adapter based on BL616/BL618. It bridges a DS4 over
Bluetooth Classic (BR/EDR) HID to a host PC via USB, appearing as a **standard wired DS4 v2**
(VID `054C` / PID `09CC`) with UAC1 audio. Games see an ordinary DualShock 4; no driver is needed.

The patched Bouffalo SDK is vendored in `third_party/bouffalo_sdk`, so a clone builds without an
external SDK checkout.

> **Unofficial project** — not affiliated with or endorsed by Sony Interactive Entertainment.
> "DualShock", "DUALSHOCK" and "PlayStation" are trademarks of Sony Interactive Entertainment.
> The USB VID/PID is emulated so the host sees a standard wired controller; use at your own risk.

## Supported Boards

| Board | Chip | USB | LED | Debug | Status |
|-------|------|-----|-----|-------|--------|
| **LCTech BL616** (default) | BL616 QFN32 | Type-C native | 1x blue (GPIO27) | External USB-TTL | **Hardware-validated in this fork** |
| **Ai-M61-32S-Kit** | BL618 QFN56 | GPIO37/38 fly-wire | RGB + white (4 LED) | Type-C CH340 | Build target only (inherited, untested here) |
| **Sipeed M0S Dock** | BL616 QFN32 | Type-C native | 2x red (GPIO27/28) | External USB-TTL | Build target only (inherited, untested here) |

**Only the LCTech BL616 has been validated on hardware in this fork.** The other two board
configurations are carried over from the upstream base and are provided as-is: they are expected
to build, but USB wiring, LED behaviour and audio timing have **not** been verified here. Use
`BOARD_TYPE=aim61` or `BOARD_TYPE=m0sdock` at your own risk, and report results if you test them.
LED pins and USB topology are selected at compile time in `board_config.h`.

## Features

- **DS4 v2 USB persona**: byte-identical 507-byte HID report descriptor, UAC1 audio function,
  endpoints `0x01` (speaker ISO OUT), `0x82` (mic ISO IN), `0x84` (HID IN).
- **Bluetooth**: BR/EDR HID host, controller pairing/reconnect, DS4 input reports `0x11` and mic
  audio reports `0x12..0x19`.
- **Audio both ways**: speaker SBC encoding (32 kHz stereo), headset-mic SBC decoding (16 kHz
  mono), 1 ms USB pacing, session/ownership protocol with cancel-witness and an F0 stall guard.
- **Input passthrough**: buttons, sticks, triggers, touchpad and gyro are forwarded to the host;
  lightbar, rumble, player LEDs and speaker/mic volume are sent to the controller.
- **Dongle config reports** `0xF6–0xF9` (not declared in the HID descriptor; Linux/macOS pass them,
  Windows drops undeclared reports).
- **Debug logging**: UART always; `DEBUG_CONSOLE=1` builds additionally expose the log through the
  DS4 feature report `0xB4` (the stock descriptor already declares it).
- **USB Full-Speed only (12 Mbps)**. High-Speed is not supported and the build rejects it.

## Build

Quick start (Linux / WSL):

```bash
sudo apt install build-essential cmake python3 curl xz-utils git
git clone <repository-url> ds4dongle-bl618
cd ds4dongle-bl618
./build.sh
```

The first build downloads the official Xuantie RISC-V toolchain (~95 MB, SHA-256 verified) into
`third_party/toolchain/` (git-ignored), because the SDK needs the T-Head `-march` extensions.
Output: `firmware/lctech616/ds4dongle-lctech616.bin` (audio + gamepad).

See [BUILD.md](BUILD.md) for Windows (WSL2 or native MSYS2), offline toolchain setup, build
options, flashing and troubleshooting.

## Flashing

Put the board into ISP mode (unplug, hold BOOT, plug in), then either:

- use **Bouffalo Dev Cube** with `firmware/<board>/flash_prog_cfg.ini`; or
- copy `BLFlashCommand` from the full Bouffalo SDK into
  `third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/` and run
  `./build.sh flash /dev/ttyACM0`.

## Debug log (0xB4)

Build with `DEBUG_CONSOLE=1`, then read the log over HID feature report `0xB4`:

```bash
python tools/hidlog.py 900 log.txt
# or:
hidapitester --vidpid 0x054C/0x09CC --open --length 64 --read-feature 0xB4 --close
```

The report is 64 bytes (ID + 63 log bytes, zero-padded). `0xB4` is a real DS4 feature report that
this firmware does not otherwise use; release builds do not touch it and keep the stock descriptor.

## Repository layout

```
src/
  main.c                 board init, BT/USB tasks, LED, input dispatch
  bt_hid_host.c          BR/EDR HID host, L2CAP control/interrupt, TX ownership
  ds4_protocol.c         DS4 input parsing, output payload, CRC
  usb_gamepad.c          composite descriptors, HID gamepad, config reports
  ds4_usb_audio.c        UAC1 audio adapter (EPs, platform callbacks)
  ds4_audio_proto.c      hardware-independent session/ownership protocol core
  ds4_audio.c            SBC speaker encoder + mic decoder tasks
  ds4_hid_desc.h         507-byte DS4 v2 HID report descriptor
  config.c, led_status.c, log_event.c, debug_console.c
third_party/bouffalo_sdk/  vendored, patched SDK (Apache-2.0)
tools/                     host-side helpers (log reader, descriptor walker, EP0 tests)
BUILD.md / BUILD_CN.md     build tutorials
SDK_CHANGES.md             what changed in the SDK and why
```

## Status

- Software: P0 audio-session remediation completed and reviewed; release candidate built from the
  default configuration.
- Hardware: accepted on LCTech BL616 for enumeration, HID, speaker, microphone, duplex, pause/resume,
  replug and Bluetooth reconnect. Full-Speed only.
- A separate **XInput (Xbox 360)** firmware variant is planned in another repository; this one keeps
  the DS4 persona.

## License

GPL-3.0 (see [LICENSE](LICENSE)). Portions are adapted from
[awalol/DS5Dongle](https://github.com/awalol/DS5Dongle) (MIT); the full notice is in [NOTICE](NOTICE).
The vendored Bouffalo SDK is Apache-2.0 (its own `LICENSE` is kept in
`third_party/bouffalo_sdk/`); see [SDK_CHANGES.md](SDK_CHANGES.md) for the local modifications.
