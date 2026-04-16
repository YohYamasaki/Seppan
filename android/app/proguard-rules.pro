# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Suppress warnings for missing annotations (common in Kotlin/Android libraries)
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit

# Keep cryptography native bindings
-keep class org.aspect_security.** { *; }

# OkHttp (used by Supabase under the hood)
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep Gson/JSON serialization if used transitively
-keepattributes Signature
-keepattributes *Annotation*
