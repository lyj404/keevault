# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep annotation
-keepattributes *Annotation*

# webdav_client (uses reflection)
-keep class com.squareup.okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# flutter_secure_storage
-keep class androidx.security.crypto.** { *; }
