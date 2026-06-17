**中文** | [English](README_EN.md)

# KeeVault

基于 Flutter 构建的跨平台 KeePass 兼容密码管理器。

![欢迎页](assets/images/screenshot.png)

## 功能特性

- **KDBX 格式支持** - 完全兼容 KeePass 数据库文件 (.kdbx)
- **密码管理** - 存储用户名、密码、网址、备注及自定义字段
- **分组管理** - 层级文件夹结构，有序组织你的条目
- **快速搜索** - 按标题、用户名、网址或备注搜索所有条目
- **密码生成器** - 内置基于密码学安全的随机密码生成
- **密码强度指示器** - 创建数据库和编辑条目时实时显示密码强度
- **回收站** - 软删除，支持恢复
- **WebDAV 云端同步** - 通过 WebDAV 协议同步数据库，支持冲突检测（ETag/mTime）与自动冲突处理
- **数据库备份** - 保存和云端同步前自动备份，支持手动备份、恢复和删除，可配置保留数量
- **自动锁定** - 无操作后自动锁定数据库，超时时间可配置
- **最近文件** - 快速访问最近打开的数据库文件，区分本地与云端来源
- **系统托盘** - 桌面端支持最小化到系统托盘，关闭窗口时可选择行为
- **跨平台** - 支持 Android、Linux、Windows

## 计划实现

- [ ] **TOTP 支持** - 一次性动态验证码生成与显示，支持两步验证场景（如 GitHub、Google 等），无需额外安装 Authenticator 应用
- [x] **文件附件** - 支持在条目中附加文件（SSH 密钥、证书、恢复密钥等），查看、添加、删除附件
- [ ] **自定义字段编辑** - 在编辑界面添加和修改自定义字段，存储安全问题答案、PIN 码等额外信息
- [ ] **Key File 认证** - 支持使用密钥文件作为第二层验证，密码 + 文件双因素解锁数据库
- [ ] **CSV 导入/导出** - 支持从 Chrome、1Password、LastPass 等导入密码，或将数据库导出为 CSV 格式
- [x] **修改主密码** - 支持更改数据库的主密码
- [ ] **条目过期时间** - 设置密码过期日期，过期后提醒用户更换
- [x] **条目历史查看** - 查看条目的历史版本记录，支持回溯和恢复旧版本

从 [Releases](https://github.com/lyj404/keevault/releases) 页面下载对应平台的安装包。

### Windows

下载 `KeeVault-*-windows-x64.zip`，解压后运行 `keevault.exe`。

### Debian / Ubuntu

下载 `.deb` 安装包，使用 `apt` 安装：

```bash
sudo apt install ./keevault_*_amd64.deb
```

### Arch Linux

通过 AUR 安装：

```bash
# 使用 yay
yay -S keevault-bin

# 或使用 paru
paru -S keevault-bin
```

### Android

下载对应架构的 APK 文件（`arm64-v8a`、`armeabi-v7a` 或 `x86_64`），安装到设备上。

## 从源码构建

### 环境要求

- Flutter SDK >= 3.12.0
- Dart SDK >= 3.12.0

```bash
git clone https://github.com/lyj404/keevault
cd keevault
flutter pub get
flutter run -d windows    # Windows
flutter run -d linux      # Linux
flutter run -d android    # Android
```

## 技术栈

- **框架**: Flutter
- **状态管理**: Riverpod
- **路由**: go_router
- **KDBX 解析**: kpasslib
- **本地存储**: flutter_secure_storage

## 友链

- [LINUX DO 社区](https://linux.do/)

## 开源协议

本项目基于 Apache License 2.0 开源 - 详见 [LICENSE](LICENSE) 文件。
