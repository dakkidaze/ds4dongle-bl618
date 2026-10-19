# DS4Dongle BL618

[English](README.md) · [编译教程](BUILD_CN.md)

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
| **LCTech BL616**（默认） | BL616 QFN32 | Type-C 原生 | 蓝色 x1（GPIO27） | 外接 USB-TTL | **本仓库已做硬件验收** |
| **Ai-M61-32S-Kit** | BL618 QFN56 | GPIO37/38 飞线 | RGB + 白（4 灯） | Type-C CH340 | 仅构建配置（继承自上游，未验证） |
| **Sipeed M0S Dock** | BL616 QFN32 | Type-C 原生 | 红色 x2（GPIO27/28） | 外接 USB-TTL | 仅构建配置（继承自上游，未验证） |

**本仓库只有 LCTech BL616 在真实硬件上验收过。** 另外两块板的配置是从上游基座继承的，按原样提供：
预期能编译，但 USB 接线、LED 行为和音频时序**没有在本仓库验证**。使用
`BOARD_TYPE=aim61` / `BOARD_TYPE=m0sdock` 风险自负；如果测了欢迎反馈结果。
LED 引脚与 USB 拓扑在 `board_config.h` 里按板型编译选择。

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
产物：`firmware/lctech616/ds4dongle-lctech616.bin`（Audio + Gamepad）。

Windows（WSL2 或原生 MSYS2）、离线工具链、构建选项、烧录与排错见 [BUILD_CN.md](BUILD_CN.md)。

## 烧录

板子进 ISP 模式（拔下 → 按住 BOOT → 插上），然后任选：

- 用 **Bouffalo Dev Cube** 加载 `firmware/<board>/flash_prog_cfg.ini`；或
- 从完整 Bouffalo SDK 拷贝 `BLFlashCommand` 到
  `third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/`，执行
  `./build.sh flash /dev/ttyACM0`。

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

- 软件：P0 音频会话整改完成并通过复审；默认配置可构建发布候选。
- 硬件：已在 LCTech BL616 上验收枚举、手柄、扬声器、麦克风、双工、暂停/恢复、拔插与蓝牙重连。
  仅 Full-Speed。
- 另有一个 **XInput（Xbox 360）** 固件变体计划在独立仓库实现；本仓库保持 DS4 形态。

## 许可证

GPL-3.0（见 [LICENSE](LICENSE)）。部分代码改编自
[awalol/DS5Dongle](https://github.com/awalol/DS5Dongle)（MIT），完整声明见 [NOTICE](NOTICE)。
vendor 的 Bouffalo SDK 为 Apache-2.0（其 `LICENSE` 保留在 `third_party/bouffalo_sdk/`）；
本地修改见 [SDK_CHANGES.md](SDK_CHANGES.md)。
