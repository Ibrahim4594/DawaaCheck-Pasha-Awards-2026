# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Supabase / OkHttp / Retrofit
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Keep Crashlytics deobfuscation info
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Camera plugin
-keep class androidx.camera.** { *; }

# Flutter Play Store deferred components — not bundled; suppress R8 missing-class
# errors for the optional Play Core split-install API references.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google ML Kit text recognition — we only bundle the Latin script model, so the
# optional Korean/Chinese/Japanese/Devanagari recognizer classes are absent.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.vision.text.**
