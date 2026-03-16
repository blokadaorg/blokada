# Preserve Flutter plugin auto-registration for the family flavor.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Preserve Adapty Android / Flutter plugin entry points used through Flutter plugin registration.
-keep class com.adapty.** { *; }
-keep class com.adapty_flutter.** { *; }
-keep class com.adapty.flutter.** { *; }
