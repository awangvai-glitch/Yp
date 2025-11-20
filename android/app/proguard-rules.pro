# Flutter/JSch specific rules
# This rule tells the Android build system (R8/ProGuard) not to remove or
# rename any classes from the JSch library during the release build process.
# This prevents ClassNotFoundException errors at runtime.
-keep class com.jcraft.jsch.** { *; }
-keep interface com.jcraft.jsch.** { *; }

# JSch has optional dependencies on jzlib and jgss.
# The -dontwarn rule tells R8 not to issue warnings if it can't find these
# classes, which prevents the build from failing.
-dontwarn com.jcraft.jzlib.**
-dontwarn org.ietf.jgss.**
