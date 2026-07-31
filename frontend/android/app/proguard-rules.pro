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

# ─── Google Play Core (split APKs / dynamic delivery) ───────────────────────
# Flutter's FlutterPlayStoreSplitApplication references Play Core classes via
# reflection. We don't ship through the Play Store (we distribute APKs
# directly), so these classes are never actually called at runtime — but R8
# still complains that they're missing. Tell R8 to ignore them.
# (R8 generates these rules into build/.../missing_rules.txt — we add them
# here proactively so the build doesn't fail.)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.assetpacks.**
-dontwarn com.google.android.play.core.review.**
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ─── Standard Android ──────────────────────────────────────────────────────
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keep class androidx.annotation.Keep
