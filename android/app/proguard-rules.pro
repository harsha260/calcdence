# Flutter Local Notifications Proguard Rules
# Keep the core plugin classes and receivers so R8 does not strip them during release
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep Gson-related classes (used by the plugin to serialize pending notifications)
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep Android classes that the broadcast receiver depends on
-keep class android.content.BroadcastReceiver { *; }
-keep interface android.content.SharedPreferences { *; }
