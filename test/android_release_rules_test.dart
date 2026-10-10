// Regression (2026-10-07): without these keep rules the release APK's
// shrinker (R8 full mode, AGP 9) broke Google ML Kit, so every camera scan,
// image upload and scanned PDF failed on the phone while debug runs and
// `flutter test` were fine. This test fails if the rules are removed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release build keeps ML Kit\'s classes', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(rules, contains('-keep class com.google.mlkit.** { *; }'));
    expect(
      rules,
      contains('-keep class com.google.android.gms.internal.mlkit_** { *; }'),
    );
  });

  test('the release build keeps the native plugins of every input', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    for (final package in [
      'com.mr.flutter.plugin.filepicker', // file_picker
      'io.flutter.plugins.imagepicker', // phone camera app
      'io.flutter.plugins.camerax', // in-app camera
      'com.eyedeadevelopment.fluttertts', // flutter_tts
      'com.google_mlkit_text_recognition',
      'com.google_mlkit_image_labeling',
    ]) {
      expect(rules, contains('-keep class $package.** { *; }'));
    }
  });

  test('shrinking is not switched off as a workaround', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, isNot(contains('isMinifyEnabled = false')));
  });

  test('the release build type uses that rules file', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('proguardFiles("proguard-rules.pro")'));
  });
}
