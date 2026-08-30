#ifndef RUNNER_LEGACY_KEYRING_MIGRATION_H_
#define RUNNER_LEGACY_KEYRING_MIGRATION_H_

// One-time migration of the flutter_secure_storage entry written by the
// pre-rename build (APPLICATION_ID com.keevault.keevault) into the entry for
// the current application id. Safe to call on every startup: it is a no-op
// when the old entry is absent or the new one already exists.
void migrate_legacy_keyring();

#endif  // RUNNER_LEGACY_KEYRING_MIGRATION_H_
