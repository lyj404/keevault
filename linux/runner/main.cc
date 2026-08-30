#include "legacy_keyring_migration.h"
#include "my_application.h"
#include "secure_storage_channel.h"

int main(int argc, char** argv) {
  // Must run before the Flutter engine registers the secure storage plugin so
  // a first write under the new identity can't race the migration.
  migrate_legacy_keyring();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
