# ── R8 / ProGuard rules for Kukku ───────────────────────────────────────────
#
# Flutter, androidx.media3 (just_audio) and androidx.media (audio_service) all
# ship consumer rules, so this file only covers what those do not.

# audio_service's service and media-button receiver are instantiated by the
# system from the manifest. AGP keeps manifest-declared classes, but keep them
# explicitly so a future manifest refactor cannot silently strip them.
-keep class com.ryanheise.audioservice.** { *; }

# audio_session is accessed reflectively by audio_service.
-keep class com.ryanheise.audio_session.** { *; }

# just_audio's platform channel implementation and Media3 entry points.
-keep class com.ryanheise.just_audio.** { *; }
-keep class androidx.media3.exoplayer.** { *; }
-keep class androidx.media3.common.** { *; }
-keep class androidx.media3.session.** { *; }

# JNI bridge (dart:ffi / jni package) is accessed reflectively at runtime.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# Media3 references optional codecs/extensions that are not bundled. Without
# these, R8 fails the build on unresolved references rather than warning.
-dontwarn androidx.media3.**
-dontwarn com.google.android.gms.**

# Kotlin/AndroidX annotation metadata used by reflection in media libraries.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Keep line numbers so release crash reports stay readable, but hide the
# original source file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
