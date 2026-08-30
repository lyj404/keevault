#include "legacy_keyring_migration.h"

#include <glib.h>
#include <libsecret/secret.h>

#include <cstring>
#include <map>
#include <string>

namespace {

// The pre-rename build (APPLICATION_ID com.keevault.keevault) stored every
// secrets as one JSON map under a single keyring item. These identifiers
// mirror what flutter_secure_storage derived from that APPLICATION_ID.
constexpr char kLegacyAccount[] = "com.keevault.keevault.secureStorage";
constexpr char kLegacySchemaName[] =
    "com.keevault.keevault/FlutterSecureStorage";
constexpr char kAccount[] = "com.keestone.keestone.secureStorage";
constexpr char kSchemaName[] = "com.keestone.keestone/FlutterSecureStorage";

// DONT_MATCH_NAME keeps xdg:schema out of the matching so this also works on
// ksecretd, which does not honor that attribute (see secure_storage_channel.cc
// for the full rationale). Both attributes must be declared because libsecret
// validates every supplied attribute against the schema.
SecretSchema MakeSchema(const char* schema_name) {
  SecretSchema schema = {};
  schema.name = const_cast<char*>(schema_name);
  schema.flags = SECRET_SCHEMA_DONT_MATCH_NAME;
  schema.attributes[0].name = const_cast<char*>("account");
  schema.attributes[0].type = SECRET_SCHEMA_ATTRIBUTE_STRING;
  schema.attributes[1].name = const_cast<char*>("key");
  schema.attributes[1].type = SECRET_SCHEMA_ATTRIBUTE_STRING;
  return schema;
}

GHashTable* MakeAttributes(const char* account, const char* key) {
  GHashTable* attributes =
      g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  g_hash_table_insert(attributes, g_strdup("account"), g_strdup(account));
  if (key != nullptr) {
    g_hash_table_insert(attributes, g_strdup("key"), g_strdup(key));
  }
  return attributes;
}

// Returns the stored secret (g_free'd by the caller) or nullptr when absent.
gchar* LookupSecret(const SecretSchema& schema, const char* account,
                    const char* key) {
  GHashTable* attributes = MakeAttributes(account, key);
  GError* error = nullptr;
  gchar* secret =
      secret_password_lookupv_sync(&schema, attributes, nullptr, &error);
  g_hash_table_destroy(attributes);
  if (error) {
    g_warning("keyring migration: lookup failed: %s", error->message);
    g_error_free(error);
    return nullptr;
  }
  if (secret != nullptr && secret[0] == '\0') {
    secret_password_free(secret);
    return nullptr;
  }
  return secret;
}

// Counts items stored under an account attribute. Used to detect whether the
// renamed app already wrote data, in which case the legacy data must not
// clobber it.
int CountAccountItems(const SecretSchema& schema, const char* account) {
  GError* error = nullptr;
  SecretService* service =
      secret_service_get_sync(SECRET_SERVICE_NONE, nullptr, &error);
  if (error) {
    g_warning("keyring migration: secret service unavailable: %s",
              error->message);
    g_error_free(error);
    return -1;
  }
  GList* items = secret_service_search_sync(service, &schema,
                                            MakeAttributes(account, nullptr),
                                            SECRET_SEARCH_ALL, nullptr, &error);
  g_object_unref(service);
  if (error) {
    g_warning("keyring migration: search failed: %s", error->message);
    g_error_free(error);
    return -1;
  }
  int count = g_list_length(items);
  g_list_free_full(items, g_object_unref);
  return count;
}

void SkipWhitespace(const char*& p) {
  while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') ++p;
}

bool ParseJsonString(const char*& p, std::string& out) {
  if (*p != '"') return false;
  ++p;
  out.clear();
  while (*p != '"') {
    if (*p == '\0') return false;
    if (*p != '\\') {
      out += *p++;
      continue;
    }
    ++p;
    switch (*p) {
      case '"': out += '"'; break;
      case '\\': out += '\\'; break;
      case '/': out += '/'; break;
      case 'b': out += '\b'; break;
      case 'f': out += '\f'; break;
      case 'n': out += '\n'; break;
      case 'r': out += '\r'; break;
      case 't': out += '\t'; break;
      case 'u': {
        auto hex4 = [&p]() -> unsigned {
          unsigned value = 0;
          for (int i = 0; i < 4; ++i) {
            char c = *++p;
            unsigned digit = c <= '9' ? static_cast<unsigned>(c - '0')
                                      : (c | 0x20) - 'a' + 10;
            value = value * 16 + digit;
          }
          return value;
        };
        unsigned code = hex4();
        if (code >= 0xD800 && code <= 0xDBFF && p[1] == '\\' && p[2] == 'u') {
          const char* backtrack = p;
          p += 2;
          unsigned low = hex4();
          if (low >= 0xDC00 && low <= 0xDFFF) {
            code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
          } else {
            p = backtrack;
          }
        }
        if (code < 0x80) {
          out += static_cast<char>(code);
        } else if (code < 0x800) {
          out += static_cast<char>(0xC0 | (code >> 6));
          out += static_cast<char>(0x80 | (code & 0x3F));
        } else if (code < 0x10000) {
          out += static_cast<char>(0xE0 | (code >> 12));
          out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
          out += static_cast<char>(0x80 | (code & 0x3F));
        } else {
          out += static_cast<char>(0xF0 | (code >> 18));
          out += static_cast<char>(0x80 | ((code >> 12) & 0x3F));
          out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
          out += static_cast<char>(0x80 | (code & 0x3F));
        }
        break;
      }
      default:
        return false;
    }
    ++p;
  }
  ++p;
  return true;
}

// Parses the flat {"key":"value", ...} object written by
// flutter_secure_storage (all values are JSON strings).
bool ParseStringMap(const char* json, std::map<std::string, std::string>& out) {
  const char* p = json;
  SkipWhitespace(p);
  if (*p++ != '{') return false;
  SkipWhitespace(p);
  if (*p == '}') return true;
  while (true) {
    SkipWhitespace(p);
    std::string key;
    if (!ParseJsonString(p, key)) return false;
    SkipWhitespace(p);
    if (*p++ != ':') return false;
    SkipWhitespace(p);
    std::string value;
    if (!ParseJsonString(p, value)) return false;
    out[key] = value;
    SkipWhitespace(p);
    if (*p == ',') {
      ++p;
      continue;
    }
    return *p == '}';
  }
}

}  // namespace

void migrate_legacy_keyring() {
  GError* error = nullptr;
  SecretService* service =
      secret_service_get_sync(SECRET_SERVICE_NONE, nullptr, &error);
  if (error) {
    g_warning("keyring migration: secret service unavailable: %s",
              error->message);
    g_error_free(error);
    return;
  }

  // Only migrate when the default collection exists and is unlocked, so a
  // locked or uninitialized KWallet/ksecretd never triggers an unlock prompt
  // at startup. A later launch will complete the migration.
  SecretCollection* collection = secret_collection_for_alias_sync(
      service, SECRET_COLLECTION_DEFAULT, SECRET_COLLECTION_NONE, nullptr,
      &error);
  g_object_unref(service);
  if (error) {
    g_warning("keyring migration: cannot resolve default collection: %s",
              error->message);
    g_error_free(error);
    return;
  }
  if (collection == nullptr) {
    return;
  }
  gboolean locked = TRUE;
  g_object_get(collection, "locked", &locked, nullptr);
  g_object_unref(collection);
  if (locked) {
    return;
  }

  SecretSchema legacy_schema = MakeSchema(kLegacySchemaName);
  gchar* legacy_secret = LookupSecret(legacy_schema, kLegacyAccount, nullptr);
  if (legacy_secret == nullptr) {
    return;
  }

  std::map<std::string, std::string> entries;
  if (!ParseStringMap(legacy_secret, entries)) {
    g_warning("keyring migration: legacy entry is not a recognized JSON map");
    secret_password_free(legacy_secret);
    return;
  }

  // Never overwrite data the renamed app already wrote (e.g. the user
  // reconfigured while the keyring was locked and migration was skipped).
  SecretSchema schema = MakeSchema(kSchemaName);
  int existing = CountAccountItems(schema, kAccount);
  if (existing != 0) {
    if (existing > 0) {
      g_message("keyring migration: new-format data already present, skipping");
    }
    secret_password_free(legacy_secret);
    return;
  }

  bool all_stored = true;
  for (const auto& entry : entries) {
    GHashTable* attributes = MakeAttributes(kAccount, entry.first.c_str());
    g_autofree gchar* label =
        g_strdup_printf("%s/%s", kSchemaName, entry.first.c_str());
    gboolean stored = secret_password_storev_sync(
        &schema, attributes, SECRET_COLLECTION_DEFAULT, label,
        entry.second.c_str(), nullptr, &error);
    g_hash_table_destroy(attributes);
    if (error) {
      g_warning("keyring migration: storing '%s' failed: %s",
                entry.first.c_str(), error->message);
      g_error_free(error);
      all_stored = false;
      break;
    }
    if (!stored) all_stored = false;
  }
  secret_password_free(legacy_secret);
  if (!all_stored) {
    return;
  }

  // Remove the legacy item only after the new per-key items are in place.
  GHashTable* legacy_attributes = MakeAttributes(kLegacyAccount, nullptr);
  secret_password_clearv_sync(&legacy_schema, legacy_attributes, nullptr,
                              &error);
  g_hash_table_destroy(legacy_attributes);
  if (error) {
    g_warning("keyring migration: clearing legacy entry failed: %s",
              error->message);
    g_error_free(error);
  }
}
