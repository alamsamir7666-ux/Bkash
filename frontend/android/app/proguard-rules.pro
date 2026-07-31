# Smart Shop Ledger — ProGuard / R8 rules
# These rules tell R8 not to strip classes that are needed at runtime
# via reflection, even though they appear unused to static analysis.

# ─── Flutter ────────────────────────────────────────────────────────────────
# Flutter's engine loads these via reflection. Keep them all.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase ───────────────────────────────────────────────────────────────
# Firebase Auth + Core use reflection to load platform implementations.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keepnames class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Prisma-style / model classes ───────────────────────────────────────────
# Keep model classes (generated Dart code references them by name).
-keep class com.smartshopledger.app.** { *; }

# ─── Standard Android ──────────────────────────────────────────────────────
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keep class androidx.annotation.Keep
