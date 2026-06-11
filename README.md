# KeeVault

基于 Flutter 构建的跨平台 KeePass 兼容密码管理器。

## 功能特性

- **KDBX 格式支持** - 完全兼容 KeePass 数据库文件 (.kdbx)
- **密码管理** - 存储用户名、密码、网址、备注及自定义字段
- **分组管理** - 层级文件夹结构，有序组织你的条目
- **快速搜索** - 按标题、用户名、网址或备注搜索所有条目
- **密码生成器** - 内置基于密码学安全的随机密码生成
- **回收站** - 软删除，支持恢复
- **WebDAV 云端同步** - 通过 WebDAV 协议同步数据库，支持冲突检测（ETag/mTime）与自动冲突处理
- **最近文件** - 快速访问最近打开的数据库文件，区分本地与云端来源
- **跨平台** - 支持 Android、iOS、Linux、macOS、Windows 和 Web

## 快速开始

### 环境要求

- Flutter SDK >= 3.12.0
- Dart SDK >= 3.12.0

### 安装

```bash
git clone https://github.com/your-username/keevault.git
cd keevault
flutter pub get
```

### 运行

```bash
flutter run -d windows    # Windows 桌面
flutter run -d chrome     # Web
flutter run -d android    # Android
```

## 技术栈

- **框架**: Flutter
- **状态管理**: Riverpod
- **路由**: go_router
- **KDBX 解析**: kpasslib
- **本地存储**: flutter_secure_storage

## 开源协议

本项目基于 Apache License 2.0 开源 - 详见 [LICENSE](LICENSE) 文件。
