# G-TRAMS Mobile — Android R8 / ProGuard Keep Rules
# Preserves runtime reflection & JNI bindings for Flutter, ML Kit Document Scanner,
# Mobile Scanner (CameraX/Barcode), Google Sign-In, Biometrics, and Encrypted Storage.

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google Play Services, Google Sign-In & ML Kit Document Scanner
-keep class com.google.android.gms.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Mobile Scanner (CameraX + ML Kit Barcode)
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Flutter Secure Storage (AndroidX Security Crypto / Google Tink)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Biometric / Local Auth
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
