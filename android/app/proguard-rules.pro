# Keep Gson classes
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.** { *; }

# Prevent obfuscation of plugin and AndroidX classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
-keep class androidx.media.** { *; }