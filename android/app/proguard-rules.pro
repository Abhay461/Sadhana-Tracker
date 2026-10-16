# ============================================================
# PROGUARD RULES FOR FLUTTER & R8 CODE OBFUSCATION
# ============================================================

# 1. Keep Flutter SDK classes and engine integration
-keep class io.flutter.embedding.** { *; }
-keepclassmembers class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# 2. Keep platform channel messages, stack trace lines, and basic engine requirements
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

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

# 5. Keep App Entry Point & Native JNI methods
-keep class com.sadhanatracker.app.MainActivity { *; }
-keepclassmembers class * {
    native <methods>;
}

# 6. Keep AndroidX & Activity EdgeToEdge
-keep class androidx.activity.** { *; }

# 7. Keep Plugins (Razorpay, OneSignal, Firebase)
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**


