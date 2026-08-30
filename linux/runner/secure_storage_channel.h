#ifndef RUNNER_SECURE_STORAGE_CHANNEL_H_
#define RUNNER_SECURE_STORAGE_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

// Registers the "keestone/secure_storage" method channel, a libsecret-backed
// keyring implementation used instead of the flutter_secure_storage plugin on
// Linux. Items are matched by plain attributes (account + key) rather than by
// the xdg:schema attribute, which ksecretd (KDE's Secret Service daemon) does
// not honor — making the plugin's reads silently fail on those systems.
void register_secure_storage_channel(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // RUNNER_SECURE_STORAGE_CHANNEL_H_
