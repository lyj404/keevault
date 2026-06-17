[中文](README.md) | **English**

# KeeVault

A cross-platform KeePass-compatible password manager built with Flutter.

![Welcome](assets/images/screenshot_en.png)

## Features

- **KDBX Format Support** - Fully compatible with KeePass database files (.kdbx)
- **Password Management** - Store usernames, passwords, URLs, notes, and custom fields
- **Group Management** - Hierarchical folder structure to organize your entries
- **Quick Search** - Search all entries by title, username, URL, or notes
- **Password Generator** - Built-in cryptographically secure random password generation
- **Password Strength Indicator** - Real-time password strength display when creating databases and editing entries
- **Recycle Bin** - Soft delete with restore support
- **WebDAV Cloud Sync** - Sync database via WebDAV protocol with conflict detection (ETag/mTime) and automatic conflict resolution
- **Database Backup** - Auto backup before save and cloud sync, manual backup/restore/delete, configurable retention count
- **Auto Lock** - Lock database after inactivity, configurable timeout
- **Recent Files** - Quick access to recently opened database files, distinguishing local and cloud sources
- **System Tray** - Desktop support for minimizing to system tray, configurable close behavior
- **Cross-Platform** - Supports Android, Linux, Windows

## Planned Features

- [ ] **TOTP Support** - Generate and display one-time passwords for two-factor authentication (GitHub, Google, etc.), eliminating the need for a separate Authenticator app
- [ ] **File Attachments** - Attach files to entries (SSH keys, certificates, recovery keys), with view, add, and delete support
- [ ] **Custom Field Editing** - Add and edit custom fields in the entry editor for storing security questions, PINs, and other extra information
- [ ] **Key File Authentication** - Support key file as a second authentication factor for password + file dual-factor database unlock
- [ ] **CSV Import/Export** - Import passwords from Chrome, 1Password, LastPass, etc., or export the database to CSV format
- [x] **Change Master Password** - Support changing the database master password
- [ ] **Entry Expiration** - Set password expiration dates with reminders when passwords expire
- [x] **Entry History Viewing** - View historical versions of entries with support for rollback and restoration

Download the corresponding platform installer from the [Releases](https://github.com/lyj404/keevault/releases) page.

### Windows

Download `KeeVault-*-windows-x64.zip`, extract and run `keevault.exe`.

### Debian / Ubuntu

Download the `.deb` package and install with `apt`:

```bash
sudo apt install ./keevault_*_amd64.deb
```

### Arch Linux

Install from AUR:

```bash
# Using yay
yay -S keevault-bin

# Or using paru
paru -S keevault-bin
```

### Android

Download the APK file for your device architecture (`arm64-v8a`, `armeabi-v7a`, or `x86_64`) and install it.

## Build from Source

### Prerequisites

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

## Tech Stack

- **Framework**: Flutter
- **State Management**: Riverpod
- **Routing**: go_router
- **KDBX Parsing**: kpasslib
- **Local Storage**: flutter_secure_storage

## Friendly Links

- [LINUX DO Community](https://linux.do/)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
