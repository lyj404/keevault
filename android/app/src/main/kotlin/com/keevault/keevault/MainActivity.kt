package com.keevault.keevault

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import android.view.autofill.AutofillManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return FlutterEngineCache.getInstance().get(KeeVaultApplication.ENGINE_ID)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.keevault.keevault/privacy",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureScreen" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.keevault.keevault/external_url",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openUrl") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val url = call.argument<String>("url")
            val uri = url?.let(Uri::parse)
            val scheme = uri?.scheme?.lowercase()
            if (
                uri == null ||
                uri.host.isNullOrEmpty() ||
                (scheme != "http" && scheme != "https")
            ) {
                result.success(false)
                return@setMethodCallHandler
            }

            try {
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addCategory(Intent.CATEGORY_BROWSABLE)
                }
                startActivity(intent)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            } catch (_: IllegalArgumentException) {
                result.success(false)
            } catch (_: SecurityException) {
                result.success(false)
            }
        }

        // Autofill status / system-settings bridge (Android O+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.keevault.keevault/autofill_control",
            ).setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDefaultService" -> result.success(isDefaultAutofillService())
                    "requestSetDefault" -> {
                        requestSetDefaultAutofillService()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun isDefaultAutofillService(): Boolean {
        val mgr = getSystemService(AutofillManager::class.java) ?: return false
        return mgr.isAutofillSupported && mgr.hasEnabledAutofillServices()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun requestSetDefaultAutofillService() {
        try {
            startActivity(Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE))
        } catch (_: ActivityNotFoundException) {
            // The dedicated "set as autofill" prompt isn't available on this
            // device/ROM. The user must enable KeeVault manually under system
            // autofill settings; nothing else we can launch reliably here.
        } catch (_: Exception) {
            // Ignore — the user can still enable it from system settings.
        }
    }
}
