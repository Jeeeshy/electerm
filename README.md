# Electerm Terminal

面向 Apple Silicon Mac 的原生 SSH 终端。在同一个窗口中使用本地 shell、连接远程服务器、浏览 SFTP 文件和查看 Linux 主机状态。界面使用 SwiftUI 和 AppKit，终端使用 SwiftTerm，SSH 使用系统 OpenSSH；不依赖 Electron。

**运行要求：**macOS 14 或更高版本，Apple Silicon（M 系列芯片）。使用成品无需安装 Xcode 或其他开发工具。

## 安装

1. 在 [GitHub Releases](https://github.com/Jeeeshy/electerm/releases) 下载正式版 `Electerm-Terminal-mac-arm64.dmg`。只有通过 Developer ID 签名、Apple 公证和 Gatekeeper 检查的安装包才会由发布流程上传到这里。如果没有这个文件，说明还没有可供下载的正式 DMG。
2. 打开 DMG，将 **Electerm Terminal** 拖到旁边的 **Applications（应用程序）**，然后推出磁盘映像。
3. 从「应用程序」打开 Electerm Terminal。无需选择数据位置。macOS 可能会按惯例询问是否打开从互联网下载的应用。

GitHub Actions 中名称带 **`-TEST`** 的 DMG 仅供开发测试，未经过 Apple 公证，其他 Mac 可能阻止打开。请勿将它当作正式版分发。

### 配置、更新与迁移

应用自动使用当前用户的 `~/Library/Application Support/Electerm Terminal/`。在 Finder 按 **⇧⌘G**，粘贴此路径即可打开。更新时只需退出并替换「应用程序」里的 `.app`，书签和设置不会跟着被替换。

| 数据 | 内容 |
| --- | --- |
| `settings.plist` | 书签和应用设置 |
| `known_hosts` | 接受过的 SSH 主机密钥 |
| `passwords.v1` | 可选的加密密码库；主密码不落盘 |
| `Temp/` | SSH 会话和 Finder 拖出暂存，退出后可清空 |

备份时退出应用，复制上述数据目录即可，`Temp/` 不必备份。**从 Build 10 便携版升级**：程序不会移动旧文件。若新版还没有自己的书签，退出新旧程序，将旧 `Electerm Data/` 里的 `settings.plist`、`known_hosts` 和 `passwords.v1`（如果存在）复制到新数据目录。若目标已有配置，请先备份；替换文件不会合并书签。自选私钥仍在原路径，需自行保管。

### 卸载与清理

- **仅卸载程序：**退出并把「应用程序」里的 `Electerm Terminal.app` 移到废纸篓。保留数据目录，下次安装还能继续使用。
- **同时删除数据：**确认不再需要书签和密码库后，在 Finder 删除 `~/Library/Application Support/Electerm Terminal/`。若曾用便携版，可另行删除自己保存的旧 `Electerm Data/`。DMG 也可删除。
- **可选的系统记录：**macOS 可能保存窗口或文件面板偏好。退出后可运行 `defaults delete local.electerm.terminal.portable`；若域不存在则无需清理。如存在，也可删除 `~/Library/Caches/local.electerm.terminal.portable` 和 `~/Library/Saved Application State/local.electerm.terminal.portable.savedState`。
- 用户下载的文件、SSH 私钥、`~/.ssh` 和 shell 历史不属于应用缓存。下载中断后若有残留，只删除确认属于该次下载的隐藏暂存项 `.electerm-<UUID>`。

## 功能

| 功能 | 使用方式 |
| --- | --- |
| 本地终端与 SSH | 支持系统 shell、SSH 配置别名、`user@host:port` 和 `ssh://user@host:port`。点「连接 SSH」可保存书签并连接，也可仅保存；「新建本地」打开本地 shell。书签支持私钥、跳板机和保存登录密码。SSH 就绪后当前标签自动显示 SFTP，底栏显示连接耗时。断开后按 `R` 在原标签重连。 |
| 标签与分屏 | 左右拖动标签调整顺序。点「分屏」选择 1–4 个已打开的标签，每个窗格有独立标签栏；点「取消分屏」回到单窗格，已有连接保留。可向多个终端广播输入。 |
| 外观与终端设置 | 深色、浅色、跟随系统三种主题同步作用于标题栏、侧栏和终端。字体、字号、光标、换行和历史缓冲可即时调整。SSH 保活、连接超时和远程 shell 探测从下次连接起生效。 |
| 快速连接与侧栏 | 快速连接固定在侧栏顶部。收起后点闪电图标即可输入 SSH 地址；切换标签或分屏焦点时，侧栏保持当前面板和展开状态。连接等待期间切换标签或手动选择侧栏时，保留你的选择。双击窗口顶部标题栏空白处可放大或还原。 |
| SFTP 文件管理 | 侧栏可拖宽。单击选中，双击文件夹进入；支持路径输入、显示隐藏文件、新建文件或目录、重命名、删除文件或空目录，以及按需显示大小和修改日期。 |
| 服务器状态 | 监控默认关闭。可选择底栏显示 CPU、内存、硬盘用量、登录用户和运行时间；后三项默认关闭，启用后每分钟合并采集一次；展开详情可查看磁盘用量、当前登录用户及各自会话数、运行时间。容量自动按 KiB、MiB、GiB 换算。详细指标面向 Linux，受服务器工具和权限限制。 |

### SFTP 上传、下载与目录跟随

- **上传与下载：**用侧栏的托盘向上箭头上传文件，用托盘向下箭头下载选中的文件或文件夹，也可右键下载。Finder 拖入、拖出支持单个普通文件。传输卡显示当前文件、进度、速度，以及完成或失败原因；支持取消。
- **下载文件夹：**选中远程目录后点下载，再选择本地父目录。按目录顺序传输，保留隐藏文件和空目录，显示当前文件进度和累计字节数，不预扫整棵目录树。符号链接和特殊文件会跳过并报告数量；不会合并或覆盖本地同名目录。
- **同名与中断：**上传拒绝覆盖远程同名文件；上传中断时远端可能留有不完整文件。单文件下载成功后才替换已确认的目标。
- **跟随终端目录：**启用「SFTP 跟随终端目录」后，可通过 shell 的 OSC 7/633 通知或 Linux 的 `/proc` 探测同步目录。SFTP 浏览和传输复用现有 SSH 认证；也可关闭跟随，独立浏览目录。

## 从源码构建

需要 Apple Silicon Mac、Git 和带 Swift 6.2 或更高版本的 Apple 工具链。首次构建需要联网获取依赖。

```sh
git clone https://github.com/Jeeeshy/electerm.git
cd electerm
sh build-mac.sh
```

脚本校验 SwiftTerm 的固定提交，运行测试并检查 Release 应用的架构、签名和终端自检，输出本地测试用 `dist/Electerm-Terminal-mac-arm64-TEST.dmg`。本地调试可运行 `sh prepare-swiftterm.sh` 和 `swift run`。构建依赖及中间产物在项目的 `.build/`，构建结束后可删除。

### 维护者：发布公证版

参考 [Apple Developer ID](https://developer.apple.com/developer-id/) 准备 **Developer ID Application** 证书（需带私钥）以及有权使用公证服务的 App Store Connect 团队 API 密钥。在仓库 **Settings → Secrets and variables → Actions → Repository secrets** 配置以下机密，不要把证书、私钥或口令提交到 Git：

| Secret | 值 |
| --- | --- |
| `DEVELOPER_ID_P12` | 导出的 Developer ID Application 证书和私钥（.p12 文件的 Base64） |
| `P12_PASSWORD` | 导出 .p12 时设置的密码 |
| `APPLE_KEY_P8` | 团队 API 私钥（.p8 文件的 Base64） |
| `APPLE_KEY_ID`、`APPLE_ISSUER_ID` | 该密钥的 Key ID 和 Issuer ID，分别保存 |

配置后在 **Actions → Native Mac (Apple Silicon) → Run workflow** 选择 `master`，勾选发布。流程使用临时钥匙串、加固运行时和安全时间戳，分别为应用及 DMG 公证、附上票据并检查 Gatekeeper；全部成功后才上传 DMG 到 Releases。没有凭据的普通推送只生成明确标记的测试包；请求正式发布时缺少凭据会直接失败。每个正式版本使用唯一的 `CFBundleVersion`。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。终端组件 [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 的[许可证](Integration/LICENSE-SwiftTerm)随应用一并分发。
