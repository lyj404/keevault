#include "secure_storage_channel.h"

#include <glib.h>
#include <libsecret/secret.h>

#include <cstring>

namespace {

constexpr char kChannelName[] = "keestone/secure_storage";
constexpr char kSchemaName[] = "com.keestone.keestone/FlutterSecureStorage";
constexpr char kAccount[] = "com.keestone.keestone.secureStorage";

// DONT_MATCH_NAME keeps xdg:schema out of the attribute matching so lookups
// work on backends that don't honor it (ksecretd) as well as ones that do
// (gnome-keyring). The account attribute is application-unique already.
SecretSchema MakeSchema() {
  SecretSchema schema = {};
  schema.name = const_cast<char*>(kSchemaName);
  schema.flags = SECRET_SCHEMA_DONT_MATCH_NAME;
  schema.attributes[0].name = const_cast<char*>("account");
  schema.attributes[0].type = SECRET_SCHEMA_ATTRIBUTE_STRING;
  schema.attributes[1].name = const_cast<char*>("key");
  schema.attributes[1].type = SECRET_SCHEMA_ATTRIBUTE_STRING;
  return schema;
}

GHashTable* MakeAttributes(const char* key) {
  GHashTable* attributes =
      g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  g_hash_table_insert(attributes, g_strdup("account"), g_strdup(kAccount));
  if (key != nullptr) {
    g_hash_table_insert(attributes, g_strdup("key"), g_strdup(key));
  }
  return attributes;
}

gchar* LookupSecret(const SecretSchema& schema, const char* key) {
  GHashTable* attributes = MakeAttributes(key);
  GError* error = nullptr;
  gchar* secret =
      secret_password_lookupv_sync(&schema, attributes, nullptr, &error);
  g_hash_table_destroy(attributes);
  if (error) {
    g_warning("secure_storage: read '%s' failed: %s", key, error->message);
    g_error_free(error);
    return nullptr;
  }
  if (secret != nullptr && secret[0] == '\0') {
    secret_password_free(secret);
    return nullptr;
  }
  return secret;
}

bool StoreSecret(const SecretSchema& schema, const char* key,
                 const char* value) {
  GHashTable* attributes = MakeAttributes(key);
  g_autofree gchar* label = g_strdup_printf("%s/%s", kSchemaName, key);
  GError* error = nullptr;
  gboolean stored = secret_password_storev_sync(
      &schema, attributes, SECRET_COLLECTION_DEFAULT, label, value, nullptr,
      &error);
  g_hash_table_destroy(attributes);
  if (error) {
    g_warning("secure_storage: write '%s' failed: %s", key, error->message);
    g_error_free(error);
    return false;
  }
  return stored;
}

bool ClearSecrets(const SecretSchema& schema, const char* key) {
  GHashTable* attributes = MakeAttributes(key);
  GError* error = nullptr;
  secret_password_clearv_sync(&schema, attributes, nullptr, &error);
  g_hash_table_destroy(attributes);
  if (error) {
    g_warning("secure_storage: clear '%s' failed: %s",
              key != nullptr ? key : "<all>", error->message);
    g_error_free(error);
    return false;
  }
  return true;
}

// Returns a map of key -> value for every unlocked item of this app.
FlValue* ReadAllSecrets(const SecretSchema& schema) {
  GError* error = nullptr;
  SecretService* service = secret_service_get_sync(
      SECRET_SERVICE_LOAD_COLLECTIONS, nullptr, &error);
  if (error) {
    g_warning("secure_storage: readAll service failed: %s", error->message);
    g_error_free(error);
    return nullptr;
  }

  GHashTable* attributes = MakeAttributes(nullptr);
  GList* items = secret_service_search_sync(
      service, &schema, attributes,
      static_cast<SecretSearchFlags>(SECRET_SEARCH_ALL |
                                     SECRET_SEARCH_LOAD_SECRETS),
      nullptr, &error);
  g_hash_table_destroy(attributes);
  if (error) {
    g_warning("secure_storage: readAll search failed: %s", error->message);
    g_error_free(error);
    g_object_unref(service);
    return nullptr;
  }

  FlValue* result = fl_value_new_map();
  for (GList* iter = items; iter != nullptr; iter = iter->next) {
    auto* item = static_cast<SecretItem*>(iter->data);
    GHashTable* item_attributes = secret_item_get_attributes(item);
    if (item_attributes == nullptr) continue;
    auto* key = static_cast<const gchar*>(
        g_hash_table_lookup(item_attributes, "key"));
    if (key == nullptr) continue;
    SecretValue* secret = secret_item_get_secret(item);
    if (secret == nullptr) continue;
    const gchar* text = secret_value_get_text(secret);
    if (text == nullptr) continue;
    fl_value_set(result, fl_value_new_string(key), fl_value_new_string(text));
  }
  g_list_free_full(items, g_object_unref);
  g_object_unref(service);
  return result;
}

const char* MapStringArg(FlValue* args, const char* name) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  g_autoptr(FlValue) name_value = fl_value_new_string(name);
  FlValue* value = fl_value_lookup(args, name_value);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}

void HandleMethodCall(FlMethodChannel* channel, FlMethodCall* method_call,
                      gpointer user_data) {
  const gchar* name = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  SecretSchema local_schema = MakeSchema();
  FlMethodResponse* response = nullptr;

  if (strcmp(name, "read") == 0) {
    const char* key = MapStringArg(args, "key");
    if (key == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "badargs", "read requires a string key", nullptr));
    } else {
      gchar* secret = LookupSecret(local_schema, key);
      g_autoptr(FlValue) result =
          secret != nullptr ? fl_value_new_string(secret) : fl_value_new_null();
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      if (secret != nullptr) secret_password_free(secret);
    }
  } else if (strcmp(name, "write") == 0) {
    const char* key = MapStringArg(args, "key");
    const char* value = MapStringArg(args, "value");
    if (key == nullptr || value == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "badargs", "write requires string key and value", nullptr));
    } else if (!StoreSecret(local_schema, key, value)) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "keyring", "failed to store secret in the keyring", nullptr));
    } else {
      response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(fl_value_new_bool(TRUE)));
    }
  } else if (strcmp(name, "delete") == 0) {
    const char* key = MapStringArg(args, "key");
    if (key == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "badargs", "delete requires a string key", nullptr));
    } else {
      ClearSecrets(local_schema, key);
      response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(fl_value_new_bool(TRUE)));
    }
  } else if (strcmp(name, "clear") == 0) {
    ClearSecrets(local_schema, nullptr);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(TRUE)));
  } else if (strcmp(name, "readAll") == 0) {
    FlValue* all = ReadAllSecrets(local_schema);
    g_autoptr(FlValue) result =
        all != nullptr ? all : fl_value_new_map();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace

void register_secure_storage_channel(FlBinaryMessenger* messenger) {
  static FlMethodChannel* channel = nullptr;
  if (channel != nullptr) return;
  channel = fl_method_channel_new(messenger, kChannelName,
                                  FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(channel, HandleMethodCall, nullptr,
                                            nullptr);
}
