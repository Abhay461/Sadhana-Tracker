# ============================================================
# PROGUARD RULES FOR FLUTTER & R8 CODE OBFUSCATION
# ============================================================

# 1. Keep Flutter SDK classes and engine integration
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Keep platform channel messages and basic engine requirements
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# 3. Prevent warning messages from missing dependency references in external packages
-dontwarn io.flutter.plugin.editing.TextInputPlugin
-dontwarn okhttp3.internal.platform.ConscryptPlatform
-dontwarn okhttp3.internal.platform.BouncyCastlePlatform
-dontwarn okhttp3.internal.platform.OpenJSSEPlatform
-dontwarn com.google.android.play.core.**

# 4. Standard serialization / gson / json requirements (if used by plugins)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }
