# DS4Dongle BL618

[English](README.md) · [编译教程](BUILD_CN.md) · [刷固件教程](FLASHING_CN.md)

基于 BL616/BL618 的 **DualShock 4（CUH-ZCT2）** 无线适配器：手柄走蓝牙经典（BR/EDR）HID，
dongle 通过 USB 呈现为**标准有线 DS4 v2**（VID `054C` / PID `09CC`），并带 UAC1 音频。
游戏把它当作普通 DualShock 4，无需安装驱动。

打补丁的 Bouffalo SDK 已 vendor 在 `third_party/bouffalo_sdk`，克隆后不需要另外下载 SDK。

> **非官方项目** —— 与索尼互动娱乐（Sony Interactive Entertainment）无关，亦未获其认可。
> "DualShock"、"DUALSHOCK" 与 "PlayStation" 是索尼互动娱乐的商标。
> USB VID/PID 仅用于模拟，使主机识别为标准有线手柄；使用风险自负。

## 支持的开发板

| 开发板 | 芯片 | USB | LED | 调试 | 状态 |
|---|---|---|---|---|---|
| **LCTech BL616**（默认） | BL616 QFN32 | Type-C 原生 | 蓝色 x1（GPIO27） | 外接 USB-TTL | **已做硬件验收** |
| **Ai-M61-32S-Kit** | BL618 QFN56 | GPIO37/38 飞线 | RGB + 白（4 灯） | Type-C CH340 | 构建已验证，硬件未测 |
| **Sipeed M0S Dock** | BL616 QFN32 | Type-C 原生 | 红色 x2（GPIO27/28） | 外接 USB-TTL | 构建已验证，硬件未测 |

**本仓库只有 LCTech BL616 在真实硬件上验收过。** 三种配置都能构建（本地已验证），但
`aim61` / `m0sdock` 的 USB 接线、LED 行为和音频时序**没有在真实硬件上验证**。使用风险自负；
如果测了欢迎反馈结果。LED 引脚与 USB 拓扑在 `board_config.h` 里按板型编译选择。

## 手柄兼容性

dongle 对主机始终呈现为有线 DS4 v2（`054C:09CC`），手柄的硬件版本只影响蓝牙侧。

| 手柄 | 状态 | 说明 |
|---|---|---|
| **DualShock 4 v2（CUH-ZCT2）** | **已做硬件验收** | 本固件的基准手柄。 |
| **DualShock 4 v1（CUH-ZCT1）** | 协议层理论上兼容，**未做硬件实测** | 与 v2 使用同一套蓝牙 HID 报告（`0x11` 状态、`0x12–0x19` 麦克风音频、`0x17` 扬声器音频）。基础输入、震动、灯条预期可用；麦克风音频与体感校准需要实机确认。 |
| **第三方 / 克隆“DS4”手柄** | **不保证兼容** | 很多克隆产品的报告 ID、payload 长度、feature report 或音频格式不同。基础 HID 输入可能可用，但麦克风、音频与校准不一定。 |

计划提供 `PROBE=1` 诊断构建：在不修改手柄的前提下，抓取手柄的 HID SDP record / report
descriptor、输入报告 ID 与长度、feature report，以及音频报告是否存在。如果你有 v1 或克隆
手柄，欢迎带着型号和探针日志开 issue。

## 功能

- **DS4 v2 USB 形态**：与真机逐字节一致的 507 字节 HID 报告描述符、UAC1 音频、
  端点 `0x01`（扬声器 ISO OUT）、`0x82`（麦克风 ISO IN）、`0x84`（HID IN）。
- **蓝牙**：BR/EDR HID host、手柄配对/重连、DS4 输入报告 `0x11` 与麦克风音频报告 `0x12..0x19`。
- **双向音频**：扬声器 SBC 编码（32 kHz 立体声）、耳机麦克风 SBC 解码（16 kHz 单声道）、
  1 ms USB 节拍、带取消见证与会话代次的音频协议、F0 卡死守卫。
- **输入透传**：按键、摇杆、扳机、触摸板、陀螺仪原样上报；灯条、震动、玩家灯、
  扬声器/麦克风音量下发给手柄。
- **Dongle 配置报告** `0xF6–0xF9`（未写进 HID 描述符；Linux/macOS 可读，Windows 会丢弃未声明报告）。
- **调试日志**：始终可从 UART 输出；`DEBUG_CONSOLE=1` 构建额外通过 DS4 的 feature report `0xB4`
  读取（真机描述符本来就声明了它）。
- **仅 USB Full-Speed（12 Mbps）**。不支持 HS，构建脚本会直接拒绝 HS 配置。

## 编译

Linux / WSL 快速开始：

```bash
sudo apt install build-essential cmake python3 curl xz-utils git
git clone <仓库地址> ds4dongle-bl618
cd ds4dongle-bl618
./build.sh
```

首次编译会下载官方 Xuantie RISC-V 工具链（约 95 MB，SHA-256 校验）到 `third_party/toolchain/`
（已 gitignore），因为 SDK 使用 T-Head 的 `-march` 扩展。
产物：`firmware/lctech616/ds4dongle-lctech616.bin` —— 默认的 `wired` 变体（Audio + Gamepad）。

Windows（WSL2 或原生 MSYS2）、离线工具链、构建选项、烧录与排错见 [BUILD_CN.md](BUILD_CN.md)。

## 发布变体

| 变体 | 构建 | 音频行为 |
|---|---|---|
| `ds4dongle-bl618-wired` | `./build.sh`（默认） | 与有线 DS4 一致：USB 音频只走耳机口；不插耳机时内置扬声器不发声。 |
| `ds4dongle-bl618-gamepadonly` | `AUDIO=0 ./build.sh` | 无 UAC1 音频功能，仅手柄。 |
| `ds4dongle-bl618-speaker` | `SPEAKER=1 ./build.sh` | 不插耳机时立体声按 L+R 下混到内置扬声器；插上耳机仍为立体声。 |

`./release.sh` 会依次构建三个变体，把固件、boot2/partition 以及每个变体各自的
`flash_prog_cfg-*.ini` 写入 `release/`（已 gitignore）。

## 烧录

板子进 ISP 模式（拔下 → 按住 BOOT → 插上）。完整教程（ini 的作用、Linux/Windows/macOS
三种路径、常见问题）见 **[FLASHING_CN.md](FLASHING_CN.md)**。

快速版：

- **Bouffalo Dev Cube**：加载 `release/flash_prog_cfg-<variant>.ini`（发布包）或
  `firmware/<board>/flash_prog_cfg.ini`（本地编译）。
- **Linux 命令行**：从完整 SDK 拷贝 `BLFlashCommand` 到
  `third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/`，然后执行
  `./build.sh flash /dev/ttyACM0`。脚本会自动把 `firmware/<board>/flash_prog_cfg.ini`
  传给工具。

## 调试日志（0xB4）

用 `DEBUG_CONSOLE=1` 构建，然后通过 HID feature report `0xB4` 读取：

```bash
python tools/hidlog.py 900 log.txt
# 或：
hidapitester --vidpid 0x054C/0x09CC --open --length 64 --read-feature 0xB4 --close
```

每次 64 字节（ID + 63 字节日志，尾部 0 补齐）。`0xB4` 是真 DS4 已有的报告，本固件平时不用它；
release 构建不改描述符。

## 目录结构

```
src/
  main.c                 板级初始化、BT/USB 任务、LED、输入分发
  bt_hid_host.c          BR/EDR HID host、L2CAP control/interrupt、TX 所有权
  ds4_protocol.c         DS4 输入解析、输出 payload、CRC
  usb_gamepad.c          组合描述符、HID 手柄、配置报告
  ds4_usb_audio.c        UAC1 音频适配层（端点、平台回调）
  ds4_audio_proto.c      硬件无关的会话/所有权协议核
  ds4_audio.c            SBC 扬声器编码 + 麦克风解码任务
  ds4_hid_desc.h         507 字节 DS4 v2 HID 报告描述符
  config.c, led_status.c, log_event.c, debug_console.c
third_party/bouffalo_sdk/  打补丁的 SDK（Apache-2.0）
tools/                     主机侧工具（日志读取、描述符检查、EP0 测试）
BUILD.md / BUILD_CN.md     编译教程
SDK_CHANGES.md             SDK 修改说明
```

## 状态

- 软件：P0 音频会话整改完成并通过复审；三个发布变体（`wired`、`gamepadonly`、`speaker`）均已
  构建验证，`./release.sh` 可产出完整烧录包。
- 硬件：已在 LCTech BL616 上验收枚举、手柄、扬声器、麦克风、双工、暂停/恢复、拔插与蓝牙重连。
  该次验收使用的是旧默认路由（不插耳机时走内置扬声器），即现在的 `speaker` 变体；`wired` 变体
  「不插耳机时内置扬声器静音」是新行为，仍需在硬件上重新验证。仅 Full-Speed。
- 另有一个 **XInput（Xbox 360）** 固件变体计划在独立仓库实现；本仓库保持 DS4 形态。

## 许可证

GPL-3.0（见 [LICENSE](LICENSE)）。部分代码改编自
[awalol/DS5Dongle](https://github.com/awalol/DS5Dongle)（MIT），完整声明见 [NOTICE](NOTICE)。
vendor 的 Bouffalo SDK 为 Apache-2.0（其 `LICENSE` 保留在 `third_party/bouffalo_sdk/`）；
本地修改见 [SDK_CHANGES.md](SDK_CHANGES.md)。
