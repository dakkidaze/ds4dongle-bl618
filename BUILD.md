# Build Guide (Linux / Windows)

This is a from-scratch guide: install the dependencies, clone the repository, build a flashable
firmware. The patched Bouffalo SDK is vendored at `third_party/bouffalo_sdk`; no separate SDK
checkout is needed.

---

## 0. Requirements

| Item | Notes |
|---|---|
| Disk | ~1.5 GB with the toolchain (the extracted toolchain is ~700 MB and can be deleted) |
| Network | the first build downloads the official RISC-V toolchain (~95 MB); later builds are offline |
| Hardware | LCTech BL616 / Ai-M61-32S-Kit / Sipeed M0S Dock (default: LCTech BL616) |

> **Why not the distro `gcc-riscv64-unknown-elf`?**
> The SDK compiles with `-march=rv32imafcpzpsfoperand_xtheade`. `xtheade` and `zpsfoperand` are
> T-Head extensions that upstream GCC does not support. The official Xuantie toolchain is
> required; `build.sh` downloads it automatically.

---

## 1. Linux (Debian / Ubuntu / WSL2, recommended)

### 1.1 Install the system packages

```bash
sudo apt update
sudo apt install -y build-essential cmake python3 curl xz-utils git
```

- `build-essential`: gcc/make and friends
- `cmake`: >= 3.15 (Ubuntu 20.04+ is fine)
- `python3`: SDK image-generation scripts
- `curl` + `xz-utils`: download and extract the toolchain
- `git`: clone the repository

Fedora equivalent:

```bash
sudo dnf install -y gcc gcc-c++ make cmake python3 curl xz git
```

### 1.2 Clone

```bash
git clone <repository-url> ds4dongle-bl618
cd ds4dongle-bl618
```

### 1.3 First build (automatic toolchain download)

```bash
./build.sh
```

On the first run it:

1. looks for `riscv64-unknown-elf-gcc` in `PATH`;
2. if not found, runs `./setup_toolchain.sh`, which downloads
   `xuantie-gcc-riscv-v2.6.1-linux-x86_64.tar.xz` (~95 MB, SHA-256 verified)
   into `third_party/toolchain/` (git-ignored);
3. builds with the system `cmake` and that toolchain.

Output:

```
firmware/lctech616/ds4dongle-lctech616.bin          # release (audio + gamepad)
firmware/lctech616/flash_prog_cfg.ini               # flash configuration
firmware/lctech616/boot2_*.bin, partition.bin       # flash package
```

### 1.4 Manual / offline toolchain

```bash
./setup_toolchain.sh          # download only (no-op if already installed)
./setup_toolchain.sh --force  # reinstall
```

Offline: download the matching archive from
<https://github.com/bouffalolab/toolchain/releases/tag/default>, extract it under
`third_party/toolchain/`, and make sure
`third_party/toolchain/<dir>/bin/riscv64-unknown-elf-gcc` exists.

Custom toolchain:

```bash
CROSS_COMPILE=/path/to/riscv64-unknown-elf- ./build.sh
SKIP_TOOLCHAIN_SETUP=1 ./build.sh   # disable the automatic download
```

### 1.5 Build options

```bash
./build.sh                    # default: LCTech BL616, audio + gamepad
AUDIO=0 ./build.sh            # diagnostic: no audio
GAMEPAD=0 ./build.sh          # diagnostic: no gamepad
DEBUG_CONSOLE=1 ./build.sh    # UART logging + HID 0xB4 log readout
MIC_DIAG=1 ./build.sh         # mic diagnostics (changes audio timing)
BOARD_TYPE=aim61 ./build.sh   # Ai-M61-32S-Kit (build-verified, hardware untested)
BOARD_TYPE=m0sdock ./build.sh # Sipeed M0S Dock (build-verified, hardware untested)
```

> Only **LCTech BL616** has been hardware-validated in this fork. All three configurations build,
> but the `aim61` / `m0sdock` USB wiring, LED behaviour and audio timing have not been verified
> on real hardware.

Other actions:

```bash
./build.sh clean      # remove build output
./build.sh rebuild    # clean + build
./build.sh strip      # drop intermediates, keep the firmware
```

### 1.6 Flashing (Linux)

1. Put the board into **ISP mode** (unplug, hold BOOT, plug in).
2. Find the serial port:
   ```bash
   ls /dev/ttyACM* /dev/ttyUSB*
   ```
3. Option A: **Bouffalo Dev Cube** (official GUI)
   - select chip BL616, UART, the port;
   - load `firmware/lctech616/flash_prog_cfg.ini` and click Download.
4. Option B: **BLFlashCommand** (not vendored; copy it from the full SDK)
   ```bash
   mkdir -p third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube
   cp -r <full-sdk>/tools/bflb_tools/bouffalo_flash_cube/* \
         third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/
   ./build.sh flash /dev/ttyACM0
   ```
5. Serial permissions (Linux only):
   ```bash
   sudo usermod -aG dialout $USER   # log out/in afterwards
   # or one-off:
   sudo chmod 666 /dev/ttyACM0
   ```

---

## 2. Windows

### 2.1 Option A: WSL2 (recommended)

WSL2 is a normal Linux environment; follow section 1:

```powershell
wsl --install -d Ubuntu
```

Then install the packages, clone and run `./build.sh` inside Ubuntu.

**Flashing**: copy `firmware/lctech616/` to Windows and use **Bouffalo Dev Cube**, or attach the
USB device to WSL with `usbipd-win`:

```powershell
winget install usbipd
usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

After `/dev/ttyACM0` appears in WSL, flash as in section 1.6 option B (copy `BLFlashCommand`
first). Note that `usbipd attach` binds the whole device; Windows temporarily loses it.

### 2.2 Option B: native Windows (MSYS2 + Windows toolchain)

Native Windows is a secondary path: usable, but less tested than WSL.

1. Install **MSYS2** (<https://www.msys2.org/>), then in the "MSYS2 MinGW 64-bit" terminal:
   ```bash
   pacman -S --needed git make cmake python
   ```
2. Download the **Windows Xuantie toolchain** from
   <https://github.com/bouffalolab/toolchain/releases/tag/default>
   (`xuantie-gcc-riscv-v2.6.1-windows-x86_64.7z`, ~77 MB) and extract it. If the archive has a
   top-level directory, point `TOOLCHAIN_PATH` at the directory that **contains `bin`**, e.g.
   `C:\toolchain_gcc_t-head_windows\xuantie-gcc-riscv-v2.6.1-windows-x86_64`.
   Verify `%TOOLCHAIN_PATH%\bin\riscv64-unknown-elf-gcc.exe` exists.
3. From the same MSYS2 MinGW terminal:
   ```bash
   export TOOLCHAIN_PATH=/c/toolchain_gcc_t-head_windows
   cd /c/path/to/ds4dongle-bl618
   cmd //c build_windows.bat
   ```
   or from cmd:
   ```bat
   set TOOLCHAIN_PATH=C:\toolchain_gcc_t-head_windows
   build_windows.bat
   ```
   `build_windows.bat` defaults:
   - SDK: `%~dp0third_party\bouffalo_sdk`
   - action: `build` (`clean` / `rebuild` are accepted)
   - `make` and `cmake` must be in `PATH`
4. Output: `firmware\lctech616\ds4dongle-lctech616.bin`.
5. Flashing: **Bouffalo Dev Cube** (Windows) with `firmware\lctech616\flash_prog_cfg.ini`, or copy
   `BLFlashCommand.exe` from the full SDK.

> The native Windows script does not download the toolchain; prepare the 7z manually.

---

## 3. Troubleshooting

| Symptom | Fix |
|---|---|
| `No RISC-V toolchain found` | run `./setup_toolchain.sh`; check `third_party/toolchain/*/bin/riscv64-unknown-elf-gcc` |
| Toolchain download fails/times out | retry, or download manually and extract (section 1.4) |
| `Permission denied` on the serial port | `sudo usermod -aG dialout $USER` and re-login, or `chmod 666` |
| `cmake` too old | upgrade to >= 3.15 (Ubuntu 20.04+ is fine) |
| Build breaks after switching boards | `./build.sh clean` or `./build.sh rebuild` (the script also auto-cleans on a changed build key) |
| No device when flashing | make sure the board is in ISP mode (BL616 ISP = `349b:6160`) and the right port is selected |
| Trying to use the official SDK | this repository vendors a patched SDK; using the stock SDK loses the P0 fixes (see `SDK_CHANGES.md`) |

---

## 4. Repository layout (build-related)

```
ds4dongle-bl618/
  src/                        application sources
  tools/                      tool sources
  third_party/bouffalo_sdk/   vendored patched SDK (Apache-2.0)
  build.sh                    build entry point
  setup_toolchain.sh          downloads the official Xuantie toolchain
  build_windows.bat           native Windows build (manual toolchain)
  SDK_CHANGES.md              what changed in the SDK and why
  misc/                       local logs / old artifacts (git-ignored)
```
