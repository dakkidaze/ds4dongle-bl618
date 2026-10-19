# 编译教程（Linux / Windows）

本文面向**全新系统**：从零安装依赖、克隆仓库、编译出可烧录的固件。
仓库已经 vendor 了打过补丁的 Bouffalo SDK（`third_party/bouffalo_sdk`），不需要另外下载 SDK。

---

## 0. 你需要什么

| 项 | 说明 |
|---|---|
| 磁盘 | 源码 + 工具链约 1.5 GB（工具链解压后约 700 MB，可删） |
| 网络 | 首次编译需要下载官方 RISC-V 工具链（约 95 MB）；之后可离线 |
| 硬件 | LCTech BL616 / Ai-M61-32S-Kit / Sipeed M0S Dock（默认 LCTech BL616） |

> **为什么不能只用 apt 的 `gcc-riscv64-unknown-elf`？**
> SDK 用 `-march=rv32imafcpzpsfoperand_xtheade` 编译，`xtheade` / `zpsfoperand` 是 T-Head 扩展，
> 上游 GCC 不支持。必须用官方 Xuantie 工具链；`build.sh` 会自动下载。

---

## 1. Linux（Debian / Ubuntu / WSL2，推荐）

### 1.1 安装系统依赖

```bash
sudo apt update
sudo apt install -y build-essential cmake python3 curl xz-utils git
```

- `build-essential`：gcc/make 等
- `cmake`：>= 3.15（Ubuntu 20.04 及以上满足）
- `python3`：SDK 的镜像生成脚本
- `curl` + `xz-utils`：下载并解压工具链
- `git`：克隆仓库

Fedora 对应：

```bash
sudo dnf install -y gcc gcc-c++ make cmake python3 curl xz git
```

### 1.2 克隆

```bash
git clone <仓库地址> ds4dongle-bl618
cd ds4dongle-bl618
```

### 1.3 首次编译（自动下载工具链）

```bash
./build.sh
```

第一次运行会：

1. 在 `PATH` 里找 `riscv64-unknown-elf-gcc`；
2. 找不到就自动执行 `./setup_toolchain.sh`，从官方 release 下载
   `xuantie-gcc-riscv-v2.6.1-linux-x86_64.tar.xz`（约 95 MB，SHA-256 校验）
   到 `third_party/toolchain/`（已 gitignore，不会进仓库）；
3. 用系统 `cmake` + 该工具链编译。

产物在：

```
firmware/lctech616/ds4dongle-lctech616.bin          # wired（默认）：Audio + Gamepad
firmware/lctech616/ds4dongle-lctech616-spk.bin      # speaker（SPEAKER=1）
firmware/lctech616/ds4dongle-lctech616-noaudio.bin  # 仅手柄（AUDIO=0）
firmware/lctech616/flash_prog_cfg.ini              # 烧录配置
firmware/lctech616/boot2_*.bin, partition.bin      # 烧录包
```

### 1.4 手动 / 离线安装工具链

```bash
./setup_toolchain.sh          # 单独下载（已安装则直接返回）
./setup_toolchain.sh --force  # 强制重装
```

离线时：从 <https://github.com/bouffalolab/toolchain/releases/tag/default> 下载对应包，
解压到 `third_party/toolchain/`，确保存在
`third_party/toolchain/<目录>/bin/riscv64-unknown-elf-gcc`。

也可以用自己的工具链：

```bash
CROSS_COMPILE=/path/to/riscv64-unknown-elf- ./build.sh
SKIP_TOOLCHAIN_SETUP=1 ./build.sh   # 禁止自动下载
```

### 1.5 构建选项

```bash
./build.sh                    # 默认：LCTech BL616，wired（Audio + Gamepad）
SPEAKER=1 ./build.sh          # 自定义：无耳机时走内置扬声器（-spk）
AUDIO=0 ./build.sh            # 诊断：无音频（-noaudio）
GAMEPAD=0 ./build.sh          # 诊断：无手柄
DEBUG_CONSOLE=1 ./build.sh    # UART 日志 + HID 0xB4 日志读取
MIC_DIAG=1 ./build.sh         # mic 诊断行为（会改变音频节拍）
BOARD_TYPE=aim61 ./build.sh   # Ai-M61-32S-Kit（构建已验证，硬件未测）
BOARD_TYPE=m0sdock ./build.sh # Sipeed M0S Dock（构建已验证，硬件未测）
```

> `wired` 是默认变体，与有线 DS4 一致：USB 音频只送到耳机口，不插耳机时内置扬声器保持静音。
> `SPEAKER=1` 才启用自定义路由——无耳机时把 L+R 下混后送到内置扬声器。它依赖音频功能，
> 与 `AUDIO=0` 同时使用会被拒绝。

> 本仓库只有 **LCTech BL616** 做过硬件验收。三种板型都能构建，但 `aim61` / `m0sdock` 的
> USB 接线、LED 与音频时序没有在真实硬件上验证。

其他动作：

```bash
./release.sh          # 构建三个变体到 release/（固件 + 烧录配置）
./build.sh clean      # 清理
./build.sh rebuild    # 清理后重编
./build.sh strip      # 只删中间文件，保留固件
```

### 1.6 烧录（Linux）

1. 让板子进入 **ISP 模式**（拔下 → 按住 BOOT → 插上）。
2. 确认串口：
   ```bash
   ls /dev/ttyACM* /dev/ttyUSB*
   ```
3. 方式 A：**Bouffalo Dev Cube**（官方 GUI）
   - 选择芯片 BL616、接口 UART、对应串口；
   - 加载 `firmware/lctech616/flash_prog_cfg.ini`，点 Download。
4. 方式 B：**BLFlashCommand**（仓库未内置，需从完整 SDK 拷贝）
   ```bash
   # 从官方 SDK 拷贝（或你已有的完整 SDK）
   mkdir -p third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube
   cp -r <完整SDK>/tools/bflb_tools/bouffalo_flash_cube/* \
         third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/
   ./build.sh flash /dev/ttyACM0
   ```
5. 串口权限（仅 Linux 需要）：
   ```bash
   sudo usermod -aG dialout $USER   # 重新登录生效
   # 或临时：
   sudo chmod 666 /dev/ttyACM0
   ```

---

## 2. Windows

### 2.1 方案 A：WSL2（推荐）

WSL2 里就是标准 Linux，按第 1 节做：

```powershell
wsl --install -d Ubuntu
```

然后在 Ubuntu 里安装依赖、克隆、`./build.sh`。

**烧录**：把 WSL 里的 `firmware/lctech616/` 拷到 Windows，用 **Bouffalo Dev Cube** 烧；
或者用 `usbipd-win` 把 USB 设备挂进 WSL：

```powershell
winget install usbipd
usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

WSL 里出现 `/dev/ttyACM0` 后，按第 1.6 节的方式 B 烧录（需要先拷 `BLFlashCommand`）。
注意：`usbipd attach` 是整设备绑定，挂进 WSL 后 Windows 侧会暂时看不到它。

### 2.2 方案 B：原生 Windows（MSYS2 + Windows 工具链）

原生 Windows 构建是**次要路径**，可用但不如 WSL 稳。

1. 安装 **MSYS2**（<https://www.msys2.org/>），在 “MSYS2 MinGW 64-bit” 终端里：
   ```bash
   pacman -S --needed git make cmake python
   ```
2. 下载 **Windows 版 Xuantie 工具链**：
   <https://github.com/bouffalolab/toolchain/releases/tag/default>
   选 `xuantie-gcc-riscv-v2.6.1-windows-x86_64.7z`（约 77 MB），用 7-Zip 解压。
   若压缩包自带顶层目录，把 `TOOLCHAIN_PATH` 指到**包含 `bin` 的那一层**，例如：
   ```
   C:\toolchain_gcc_t-head_windows\xuantie-gcc-riscv-v2.6.1-windows-x86_64
   ```
   确认存在 `%TOOLCHAIN_PATH%\bin\riscv64-unknown-elf-gcc.exe`。
3. 在同一个 MSYS2 MinGW 终端里设置并编译：
   ```bash
   export TOOLCHAIN_PATH=/c/toolchain_gcc_t-head_windows
   cd /c/path/to/ds4dongle-bl618
   cmd //c build_windows.bat
   ```
   或直接在 cmd 里：
   ```bat
   set TOOLCHAIN_PATH=C:\toolchain_gcc_t-head_windows
   build_windows.bat
   ```
   `build_windows.bat` 默认：
   - SDK：`%~dp0third_party\bouffalo_sdk`
   - 动作：`build`，可传 `clean` / `rebuild`
   - 需要 `make` 和 `cmake` 在 `PATH` 里
4. 产物：`firmware\lctech616\ds4dongle-lctech616.bin`。
5. 烧录：**Bouffalo Dev Cube**（Windows）加载 `firmware\lctech616\flash_prog_cfg.ini`；
   或把完整 SDK 的 `BLFlashCommand.exe` 放到对应目录后使用。

> 原生 Windows 的 `build_windows.bat` 没有自动下载工具链；必须手动准备上面的 7z。

---

## 3. 常见问题

| 现象 | 处理 |
|---|---|
| `No RISC-V toolchain found` | 运行 `./setup_toolchain.sh`；或检查 `third_party/toolchain/*/bin/riscv64-unknown-elf-gcc` |
| 工具链下载失败/超时 | 重试；或按 1.4 手动下载并解压 |
| 串口打不开（Permission denied） | `sudo usermod -aG dialout $USER` 后重新登录，或临时 `chmod 666` |
| `cmake` 版本过低 | 升级到 >= 3.15（Ubuntu 20.04+ 即可） |
| 切换板型后编译异常 | 用 `./build.sh clean` 或 `./build.sh rebuild`（脚本也会按构建键自动清理） |
| 烧录时找不到设备 | 确认板子已进 ISP（BL616 ISP 显示为 `349b:6160`），并选对串口 |
| 想用官方 SDK 复现 | 本仓库的 SDK 已打补丁，必须用 `third_party/bouffalo_sdk`；改用官方 SDK 会丢失 P0 修复（见 `SDK_CHANGES.md`） |

---

## 4. 仓库结构（构建相关）

```
ds4dongle-bl618/
  src/                        应用源码
  tools/                      工具源码
  third_party/bouffalo_sdk/   vendor 的补丁 SDK（Apache-2.0）
  build.sh                    构建入口
  setup_toolchain.sh          下载官方 Xuantie 工具链
  build_windows.bat           原生 Windows 构建（需手动准备工具链）
  SDK_CHANGES.md              SDK 修改说明
  misc/                       本地日志/旧产物（gitignore，克隆后不存在）
```
