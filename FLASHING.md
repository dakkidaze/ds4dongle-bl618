# Flashing Guide

This guide covers the **release bundle** and a **local build**. It explains what the `.ini` files
are, when you need them, and the known-good flashing paths on Linux, Windows and macOS.

> The dongle is a BL616/BL618 board. Flashing uses the chip's **ROM ISP mode over UART**, not the
> USB device port that the dongle exposes to the PC.

## 1. What is in the bundle?

| File | Role |
|---|---|
| `ds4dongle-bl618-<variant>.bin` | Application image. This is the firmware you want to run. |
| `boot2_bl616_isp_release_v8.1.8.bin` | Second-stage bootloader. Always written at `0x000000`. |
| `partition.bin` | Partition table. Always written at `0xE000`. Defines where the application partition lives. |
| `flash_prog_cfg-<variant>.ini` | **Flash layout manifest** for the flashing tool. It names the three files and their addresses. It is not firmware and is not read by the chip. |

On this 4 MB BL616 layout the partition table places the `FW` entry at `0x10000`. The ini uses
`address = @partition`, so the tool reads `partition.bin` and resolves that address for you.

The ini also sets:

- `erase = 1` — erase the sections being programmed before writing (not a whole-chip erase);
- `skip_mode = 0x0, 0x0` — no skipped region;
- `boot2_isp_mode = 0` — normal boot2, not ISP boot2.

## 2. Do I need the ini?

| Flashing path | Is the ini used? | Notes |
|---|---|---|
| **Bouffalo Dev Cube** (GUI) | **Yes** | Load the per-variant ini; it fills the file/address table. |
| `./build.sh flash /dev/ttyACM0` (Linux) | **Yes, but automatic** | The script runs `BLFlashCommand ... --config=flash_prog_cfg.ini` from `firmware/<board>/`. You do not type the path. |
| `BLFlashCommand` manually | **Recommended** | `--config=flash_prog_cfg-<variant>.ini` is the safe way to get boot2/partition/application addresses. |
| Raw `--firmware` + `--addr` | No | Possible, but you must also flash boot2 and partition and know the application offset (`0x10000` here). Not recommended. |

So on Linux the ini **is** still used; `build.sh` hides it. The release bundle has one ini per
variant because the application file is renamed. A locally built firmware has
`firmware/<board>/flash_prog_cfg.ini`, which points at the build output's file name.

**If you rename a file, edit the matching `filedir = ./...` line in the ini.**

## 3. Prerequisites

1. A UART connection to the board. The LCTech BL616 uses an **external USB-TTL** on its UART
   header for flashing/debug; its Type-C port is the device USB, not the ISP UART.
2. A terminal program is not needed; the flashing tool opens the port directly.
3. Put the board into **ISP mode**: unplug it, hold **BOOT**, plug it in, release **BOOT** after
   the port appears.
4. Find the serial port:
   ```bash
   # Linux
   ls /dev/ttyACM* /dev/ttyUSB*
   # macOS
   ls /dev/tty.usbserial*
   ```
   On Linux, add yourself to `dialout` (log out/in afterwards) or use a one-off `chmod`:
   ```bash
   sudo usermod -aG dialout "$USER"
   # or:
   sudo chmod 666 /dev/ttyACM0
   ```
5. `BLFlashCommand` is **not vendored** in this repository. Use **Bouffalo Dev Cube**, or copy the
   tool from the full Bouffalo SDK:
   ```bash
   mkdir -p third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube
   cp -r <full-sdk>/tools/bflb_tools/bouffalo_flash_cube/* \
         third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/
   ```
   The copy includes `BLFlashCommand-ubuntu`, `BLFlashCommand-macos`, `BLFlashCommand.exe`, etc.

## 4. Option A — Bouffalo Dev Cube (all platforms, recommended)

1. Put the board into ISP mode.
2. Start **Bouffalo Dev Cube**, select chip **BL616**, interface **UART**, and the serial port.
3. Load the ini for the variant you want:
   - `release/flash_prog_cfg-wired.ini`
   - `release/flash_prog_cfg-gamepadonly.ini`
   - `release/flash_prog_cfg-speaker.ini`
   (or `firmware/<board>/flash_prog_cfg.ini` for a local build).
4. Click **Download/Flash**.
5. Keep the `.bin`, `boot2_*.bin`, `partition.bin` and `.ini` together in one directory. The ini
   uses relative paths; if Dev Cube cannot find a file, start it from that directory or replace
   the relative `filedir` values with absolute paths.

## 5. Option B — Linux CLI

### 5.1 Local build

```bash
./build.sh
./build.sh flash /dev/ttyACM0
```

`build.sh flash` changes into `firmware/<board>/` and runs `BLFlashCommand` with
`--config=flash_prog_cfg.ini`. The ini is used automatically. If `BLFlashCommand` is missing, see
section 3.

### 5.2 Release bundle (manual)

```bash
cd release
/path/to/BLFlashCommand-ubuntu \
  --interface=uart --baudrate=2000000 \
  --port=/dev/ttyACM0 --chipname=bl616 --cpu_id= \
  --config=flash_prog_cfg-wired.ini
```

Replace `wired` with `gamepadonly` or `speaker` as needed, and use
`BLFlashCommand-macos` on macOS. Run the command from the directory containing the bundle so the
relative `filedir` paths resolve.

## 6. Option C — Windows

**Recommended: Bouffalo Dev Cube** with `release\flash_prog_cfg-<variant>.ini` (or
`firmware\lctech616\flash_prog_cfg.ini` for a local build), following section 4.

`build_windows.bat flash COMx` calls the SDK's `make flash` target, which looks for a
`flash_prog_cfg.ini` in the repository root. This project generates the ini under
`firmware\<board>\`, so use Dev Cube or run `BLFlashCommand.exe` from that directory:

```bat
cd firmware\lctech616
...\bouffalo_flash_cube\BLFlashCommand.exe --interface=uart --baudrate=2000000 ^
  --port=COM5 --chipname=bl616 --cpu_id= --config=flash_prog_cfg.ini
```

## 7. Which variant should I flash?

| Variant | Use it when |
|---|---|
| `wired` | You want the dongle to behave like a wired DS4: USB audio only through the headset jack; the built-in speaker is silent with no headset. |
| `gamepadonly` | You do not need USB audio; gamepad only. |
| `speaker` | You want the controller's built-in speaker to play USB audio (L+R downmix) when no headset is plugged. |

All three present the same DS4 v2 USB persona (`054C:09CC`); only the audio routing differs.

## 8. Troubleshooting

| Symptom | Check |
|---|---|
| No serial port | Board not in ISP mode, wrong USB-TTL wiring, missing USB-UART driver (CH340 on Ai-M61-32S-Kit). |
| `Permission denied` on Linux | `dialout` group or `sudo chmod 666 /dev/ttyACM0`. |
| `BLFlashCommand` not found | Copy it from the full SDK (section 3) or use Dev Cube. |
| Tool cannot find `boot2`/`partition`/firmware | Run from the bundle directory; keep the files together; check the `filedir` lines. |
| Flash succeeds but the dongle does not enumerate | Re-check the variant, the UART port and the board's BOOT/ISP state; verify with `lsusb` and `dmesg`. |
| Wrong audio behaviour | Flash the matching variant and its matching ini; `wired` and `speaker` differ only in the no-headset routing. |

After flashing, the host should show `054c:09cc` (wired DS4 v2). On Linux:

```bash
lsusb | grep -i 054c
dmesg | tail -n 40
aplay -l
arecord -l
```

## 9. More

- Build options: [BUILD.md](BUILD.md) / [BUILD_CN.md](BUILD_CN.md)
- Variants and controller compatibility: [README.md](README.md) / [README_CN.md](README_CN.md)
