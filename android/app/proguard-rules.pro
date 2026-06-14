# Flutter wrapper — keep Flutter embedding & plugin entry points.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep annotations used for reflection-based serialization.
-keepattributes *Annotation*

# Suppress notes about missing optional desugar classes.
-dontwarn java.lang.invoke.**
