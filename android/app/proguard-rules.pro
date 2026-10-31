# ==============================================================================
# ProGuard / R8 Hardening Rules - Sentinela Radar v1.0.0
# ==============================================================================

# Flutter & Dart wrappers
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Native Plugins & Bridges
-keep class com.baseflow.geolocator.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }

# SQLite3 & R*Tree Native Bindings
-keep class org.sqlite.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Platform Channels & Automotive Serialization
-keep class br.com.sentinela.** { *; }

# Suppress harmless warnings for unused dependencies
-dontwarn io.flutter.**
-dontwarn okio.**
