[中文](README.md) | **English**

# KeeVault

A cross-platform KeePass-compatible password manager built with Flutter.

![Welcome](assets/images/screenshot_en.png)

## Features

### Core
- **WebDAV Cloud Sync** - Sync database via WebDAV protocol with conflict detection and automatic resolution
- **TOTP Support** - Generate one-time passwords, KeePassXC storage format compatible, QR code scanning setup
- **Fingerprint Unlock** - Android support for unlocking databases with fingerprint/face recognition
- **Key File Authentication** - Support key file as a second authentication factor for dual-factor unlock
- **CSV Import/Export** - Import passwords from Chrome, 1Password, LastPass, Bitwarden, etc.
- **KDBX Export** - Export full KeePass database file
- **File Attachments** - Attach files to entries (SSH keys, certificates, recovery keys)
- **Entry History** - View historical versions of entries with rollback and restoration support

### Security & Management
- **Database Backup** - Auto backup, manual backup, configurable retention, restore from backup
- **Password Generator** - Customizable length, character types, special symbols for strong passwords
- **Password Strength Indicator** - Visual password strength evaluation
- **Change Master Password** - Change database master password
- **Recycle Bin** - Soft delete entries with restore capability
- **Auto Lock** - Configurable inactivity timeout to auto-lock database (1-60 minutes)
- **Auto Save** - Configurable inactivity timeout to auto-save database (15-300 seconds)
- **Clipboard Auto-Clear** - Automatically clear clipboard 30 seconds after copying password
- **Password Expiration Reminders** - Desktop notifications for passwords about to expire (1-30 days)

### Organization & Search
- **Tags System** - Tag entries for organization, filter by tags
- **Batch Operations** - Batch delete, move, edit tags for multiple entries
- **Custom Fields** - Add custom fields to entries with field protection option
- **Group Management** - Nested group paths, move entries between groups
- **Fuzzy Search** - Fast search across all entries with debounced input
- **Entry Sorting** - Sort by title, creation date, modification date, expiration

### Desktop Features
- **System Tray** - Minimize to system tray (Windows/Linux)
- **Keyboard Shortcuts** - Ctrl+F search, Ctrl+S save, Ctrl+B copy username, Ctrl+C copy password, Ctrl+U copy URL, Ctrl+T copy TOTP
- **Close Behavior** - Configurable window close action (minimize to tray, exit, ask every time)

### UI & Experience
- **Cross-Platform** - Supports Android, Linux, Windows
- **Theme Switching** - Light/Dark/System theme
- **Multi-Language** - Chinese/English/System language
- **Responsive Layout** - Wide/narrow layout adaptive
- **Breadcrumb Navigation** - Hierarchical group navigation

## CSV Import Format

Supports automatic detection of common password manager CSV formats - no fixed template required:

### Supported Column Names (Case-Insensitive)

| Field | Supported Column Names |
|-------|----------------------|
| Title | `Title`, `Name`, `Entry Name` |
| Username | `Username`, `User`, `Login`, `Login_Username` |
| Password | `Password`, `Pass`, `Passwd`, `Login_Password` |
| URL | `URL`, `URI`, `Website`, `Web Site`, `Login_URI` |
| Notes | `Notes`, `Note`, `Extra`, `Comments`, `Comment` |
| Group | `Group`, `Grouping`, `Folder`, `Folders`, `Path` |
| TOTP | `TOTP`, `OTPAuth`, `Login_TOTP`, `OTP` |

### Supported Password Manager Formats

**Chrome / Google Password Manager**
```csv
name,url,username,password
```

**1Password**
```csv
Title,Username,Password,URL,Notes
```

**LastPass**
```csv
url,username,password,totp,extra,name,grouping,fav
```

**Bitwarden**
```csv
folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp
```

**KeePass**
```csv
Group,Title,Username,Password,URL,Notes
```

### Notes

- Delimiter auto-detection: comma (`,`), semicolon (`;`), and tab supported
- Automatic UTF-8 BOM stripping
- Automatic header row detection
- Unrecognized columns are imported as custom fields
- Supports nested group paths (e.g., `Email/Work`)

### Export Formats

- **CSV Export**: KeePass-compatible format (`Group,Title,Username,Password,URL,Notes`)
- **KDBX Export**: Full KeePass database file export

---

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
- **Biometric Auth**: local_auth
- **File Picking**: file_picker
- **CSV Parsing**: csv
- **OTP Generation**: otp
- **QR Code Scanning**: mobile_scanner
- **System Tray**: system_tray / dart_xdg_status_notifier_item
- **Window Management**: window_manager
- **WebDAV Sync**: webdav_client
- **Local Notifications**: flutter_local_notifications
- **Windows Native Notifications**: win32 / ffi
- **Logging**: logger

## Friendly Links

- [LINUX DO Community](https://linux.do/)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
