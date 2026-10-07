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
