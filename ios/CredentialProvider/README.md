# KeeVault Autofill — iOS Credential Provider Extension

Headless edits cannot add a new Xcode target or wire capabilities, so the
following one-time setup must be performed in Xcode. The extension source,
Info.plist, and entitlements files already exist in this directory.

## 1. Add the extension target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File → New → Target… → **Credential Provider Extension** (iOS).
3. Name it `CredentialProvider`, language Swift, embed in Runner.
4. Replace the generated `*.swift`/`Info.plist` with the files in this folder:
   `CredentialProviderViewController.swift`, `SnapshotStore.swift`,
   `Matcher.swift`, `Info.plist`.
5. Set the target's Info.plist to `CredentialProvider/Info.plist` and the
   principal class to `CredentialProviderViewController`.
6. Add `import CryptoKit` (available iOS 13+, already used by `SnapshotStore`).

## 2. Capabilities (Runner AND CredentialProvider)

Enable on **both** the Runner app target and the CredentialProvider target:

- **App Groups** → add `group.com.keevault.keevault`
- **Keychain Sharing** → group name `group.com.keevault.keevault`

This makes `Runner.entitlements` and `CredentialProvider.entitlements`
(provided here) take effect. If Xcode regenerates its own entitlements files,
ensure the `application-groups` and `keychain-access-groups` entries above are
present in both.

## 3. Access-group alignment (IMPORTANT)

The AES snapshot key is written to the shared Keychain by the Dart side via
`flutter_secure_storage` with `IOSOptions(groupId: "group.com.keevault.keevault")`,
which sets `kSecAttrAccessGroup` to that literal string. `SnapshotStore.swift`
reads with the same literal. If on device the extension read fails with
`errSecItemNotFound`, the actual stored access group is most likely
team-prefixed (`<TEAMID>group.com.keevault.keevault`). In that case change
`SnapshotStore.appGroupId` (used as `kSecAttrAccessGroup`) **and** the Dart
`_appGroupId` in `lib/features/autofill/services/autofill_snapshot_service.dart`
to the identical prefixed string, and update the App Group id accordingly.
Both sides must use the exact same string.

## 4. URL scheme (optional)

To let the extension offer "Open KeeVault" when the vault is locked, register
a `keevault` URL scheme on the Runner target and handle it in
`AppDelegate.swift` (route to the unlock screen). The extension calls
`keevault://unlock`.

## 5. Verify

Build to a device, unlock the vault with autofill enabled, then trigger iOS
autofill in Safari on a login page. KeeVault should appear under
Settings → Passwords → Password Options once enabled.
