# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
# ── Google ML Kit (text recognition + image labeling) ──────────────────────
# R8 full mode (default with AGP 9) strips or renames members of ML Kit's
# internal classes that it reads by reflection (protobuf-lite style). The
# release APK then failed every OCR call with
#   NullPointerException: ... Object.getClass() on a null object reference
# in com.google.android.gms.internal.mlkit_vision_common.* (2026-10-07), so
# every camera scan, image upload and scanned PDF page "could not be opened".
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.odml.** { *; }
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses

# ── Other native plugins used by the document inputs (2026-10-07) ──────────
# These talk to Dart over method channels (names are strings, so renaming is
# safe today), but native code and future plugin versions may look classes up
# by name. Keeping them costs a few kilobytes and rules out a release-only
# break in the inputs the app depends on. Shrinking stays on.
# file_picker (Android implementation: android_file_picker)
-keep class com.mr.flutter.plugin.filepicker.** { *; }
# image_picker (phone camera app fallback)
-keep class io.flutter.plugins.imagepicker.** { *; }
# camera (CameraX implementation, Pigeon proxy classes)
-keep class io.flutter.plugins.camerax.** { *; }
# flutter_tts
-keep class com.eyedeadevelopment.fluttertts.** { *; }
# speech_to_text
-keep class com.csdcorp.speech_to_text.** { *; }
# google_mlkit_* Flutter plugins (the ML Kit SDK itself is kept above)
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_image_labeling.** { *; }
# path_provider_android calls Android through JNI (package:jni)
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
# pdfrx renders with PDFium through dart:ffi (a native library, no Java
# classes to keep); its .so files must stay in the APK, which R8 never strips.

# ElevenLabs voice agent SDK and the LiveKit/WebRTC stack it uses (rules from
# the SDK's documentation; WebRTC is called from native code by name).
-keep class io.elevenlabs.** { *; }
-keep class io.livekit.** { *; }
-keep class livekit.** { *; }
-keep class org.webrtc.** { *; }
-keepattributes *Annotation*
