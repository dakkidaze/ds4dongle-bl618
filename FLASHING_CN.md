# 刷固件教程

本教程覆盖 **Release 发布包** 和 **本地编译产物**，并说明 `.ini` 文件的作用、
什么时候需要它，以及 Linux / Windows / macOS 下可用的烧录路径。

> dongle 是 BL616/BL618 板子。烧录走芯片的 **ROM ISP + UART**，不是 dongle 暴露给 PC 的
> USB 设备口。

## 1. 发布包里都有什么？

| 文件 | 作用 |
|---|---|
| `ds4dongle-bl618-<variant>.bin` | 应用固件，真正要跑的程序。 |
| `boot2_bl616_isp_release_v8.1.8.bin` | 二级 bootloader，固定写到 `0x000000`。 |
| `partition.bin` | 分区表，固定写到 `0xE000`，里面定义了应用分区的位置。 |
| `flash_prog_cfg-<variant>.ini` | **烧录布局清单**，告诉烧录工具三个文件分别写到哪里。它不是固件，芯片也不读它。 |

这块 4 MB BL616 布局把 `FW` 分区放在 `0x10000`。ini 里写的是 `address = @partition`，
烧录工具会读 `partition.bin` 自动解析出这个地址。

ini 里还有：

- `erase = 1` —— 写入前擦除本次要编程的区块（不是整片擦除）；
- `skip_mode = 0x0, 0x0` —— 不跳过任何区域；
- `boot2_isp_mode = 0` —— 使用正常 boot2，不是 ISP boot2。

## 2. 到底需不需要 ini？

| 烧录方式 | 是否用 ini？ | 说明 |
|---|---|---|
| **Bouffalo Dev Cube**（图形界面） | **需要** | 加载对应变体的 ini，工具会自动填好文件和地址。 |
| `./build.sh flash /dev/ttyACM0`（Linux） | **需要，但脚本自动处理** | 脚本会进入 `firmware/<board>/`，执行 `BLFlashCommand ... --config=flash_prog_cfg.ini`，你不用手写路径。 |
| 手动运行 `BLFlashCommand` | **推荐使用** | 用 `--config=flash_prog_cfg-<variant>.ini` 最稳，boot2/分区/应用的地址都由它给出。 |
| 直接 `--firmware` + `--addr` | 不用 | 理论上可以，但你还要自己烧 boot2 和分区表，并知道应用偏移（这里是 `0x10000`）。不推荐。 |

所以 Linux 下 **并不是不需要 ini**，只是 `build.sh` 帮你调用了。发布包每个变体一个 ini，
是因为应用文件名被重命名了；本地编译产物的 ini 在 `firmware/<board>/flash_prog_cfg.ini`，
指向编译输出的文件名。

**如果你改了文件名，记得同步修改 ini 里对应的 `filedir = ./...`。**

## 3. 准备工作

1. 用 UART 连接板子。LCTech BL616 的烧录/调试需要**外接 USB-TTL** 接到 UART 排针；
   Type-C 口是设备 USB，不是 ISP UART。
2. 不需要串口终端，烧录工具会直接占用串口。
3. 让板子进入 **ISP 模式**：拔下 → 按住 **BOOT** → 插上 → 等串口出现后松开 **BOOT**。
4. 找到串口：
   ```bash
   # Linux
   ls /dev/ttyACM* /dev/ttyUSB*
   # macOS
   ls /dev/tty.usbserial*
   ```
   Linux 下把当前用户加入 `dialout`（重新登录生效），或临时改权限：
   ```bash
   sudo usermod -aG dialout "$USER"
   # 或者：
   sudo chmod 666 /dev/ttyACM0
   ```
5. `BLFlashCommand` **没有** vendor 进本仓库。请用 **Bouffalo Dev Cube**，或从完整 Bouffalo SDK
   拷贝：
   ```bash
   mkdir -p third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube
   cp -r <full-sdk>/tools/bflb_tools/bouffalo_flash_cube/* \
         third_party/bouffalo_sdk/tools/bflb_tools/bouffalo_flash_cube/
   ```
   里面有 `BLFlashCommand-ubuntu`、`BLFlashCommand-macos`、`BLFlashCommand.exe` 等。

## 4. 方式 A —— Bouffalo Dev Cube（全平台，推荐）

1. 板子进 ISP 模式。
2. 打开 **Bouffalo Dev Cube**，芯片选 **BL616**，接口选 **UART**，选对串口。
3. 加载对应变体的 ini：
   - `release/flash_prog_cfg-wired.ini`
   - `release/flash_prog_cfg-gamepadonly.ini`
   - `release/flash_prog_cfg-speaker.ini`
   （本地编译则用 `firmware/<board>/flash_prog_cfg.ini`）。
4. 点 **Download/Flash**。
5. `.bin`、`boot2_*.bin`、`partition.bin` 和 `.ini` 要放在同一目录。ini 用的是相对路径；
   如果 Dev Cube 找不到文件，从该目录启动它，或把 `filedir` 改成绝对路径。

## 5. 方式 B —— Linux 命令行

### 5.1 本地编译

```bash
./build.sh
./build.sh flash /dev/ttyACM0
```

`build.sh flash` 会进入 `firmware/<board>/`，用 `--config=flash_prog_cfg.ini` 调
`BLFlashCommand`，ini 是自动使用的。工具缺失时见第 3 节。

### 5.2 Release 发布包（手动）

```bash
cd release
/path/to/BLFlashCommand-ubuntu \
  --interface=uart --baudrate=2000000 \
  --port=/dev/ttyACM0 --chipname=bl616 --cpu_id= \
  --config=flash_prog_cfg-wired.ini
```

把 `wired` 换成 `gamepadonly` 或 `speaker` 即可；macOS 用 `BLFlashCommand-macos`。
命令要在发布包目录里执行，ini 的相对路径才能找到文件。

## 6. 方式 C —— Windows

**推荐用 Bouffalo Dev Cube**，加载 `release\flash_prog_cfg-<variant>.ini`（本地编译则用
`firmware\lctech616\flash_prog_cfg.ini`），步骤同第 4 节。

`build_windows.bat flash COMx` 调的是 SDK 的 `make flash`，它会在仓库根目录找
`flash_prog_cfg.ini`；本项目的 ini 生成在 `firmware\<board>\` 下，所以请用 Dev Cube，
或者进入该目录手动运行 `BLFlashCommand.exe`：

```bat
cd firmware\lctech616
...\bouffalo_flash_cube\BLFlashCommand.exe --interface=uart --baudrate=2000000 ^
  --port=COM5 --chipname=bl616 --cpu_id= --config=flash_prog_cfg.ini
```

## 7. 该刷哪个变体？

| 变体 | 适用场景 |
|---|---|
| `wired` | 想要和有线 DS4 一致：USB 音频只走耳机口；不插耳机时内置扬声器静音。 |
| `gamepadonly` | 不需要 USB 音频，只要手柄。 |
| `speaker` | 希望不插耳机时，USB 音频经 L+R 下混后从手柄内置扬声器播放。 |

三个变体对主机都呈现同一个 DS4 v2 USB 形态（`054C:09CC`），只有音频路由不同。

## 8. 常见问题

| 现象 | 检查 |
|---|---|
| 找不到串口 | 板子没进 ISP、USB-TTL 接线不对、缺 USB-UART 驱动（Ai-M61-32S-Kit 是 CH340）。 |
| Linux 报 `Permission denied` | 加入 `dialout` 组，或 `sudo chmod 666 /dev/ttyACM0`。 |
| 找不到 `BLFlashCommand` | 从完整 SDK 拷贝（第 3 节），或改用 Dev Cube。 |
| 工具找不到 `boot2` / `partition` / 固件 | 在发布包目录执行；保持文件在同一目录；检查 `filedir`。 |
| 烧录成功但 dongle 不枚举 | 确认变体、串口和 BOOT/ISP 状态；用 `lsusb`、`dmesg` 查。 |
| 音频行为不对 | 刷对应变体和对应 ini；`wired` 与 `speaker` 只差无耳机时的路由。 |

烧录后主机应看到 `054c:09cc`（有线 DS4 v2）。Linux 下可以查：

```bash
lsusb | grep -i 054c
dmesg | tail -n 40
aplay -l
arecord -l
```

## 9. 相关文档

- 编译选项：[BUILD.md](BUILD.md) / [BUILD_CN.md](BUILD_CN.md)
- 变体与手柄兼容性：[README.md](README.md) / [README_CN.md](README_CN.md)
