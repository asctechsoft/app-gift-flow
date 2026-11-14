# R8 rules for release builds (flavor product / any --release).
# Flutter's own rules are added by the Flutter Gradle plugin; these cover the
# parts that are reached only by name (manifest, platform channels, plugins).

-keep class com.asc.gift_flow.** { *; }

# ML Kit text recognition: only the Latin recognizer is bundled; the other
# script options are referenced by name but not shipped.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep file names and line numbers so stack traces stay readable.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
