# Keep Play Core library
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep your application classes that use native code
-keep class com.example.my_app_984.** { *; }

# Keep serialization libraries
-keepattributes *Annotation*
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Keep native methods
-keepclasseswithmembernames class * {
	native <methods>;
}