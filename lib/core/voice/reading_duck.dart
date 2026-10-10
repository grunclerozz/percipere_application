import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the user is speaking over a document being read aloud: the
/// Reader pauses its voice (so the recognizer hears the user, not the app)
/// and resumes the sentence when this goes back to false, unless the
/// command changed what it is doing. Set by the voice controller.
class ReadingDuck extends Notifier<bool> {
  @override
  bool build() => false;

  /// Pauses ([on]) or releases the reading voice.
  void set({required bool on}) {
    if (state != on) state = on;
  }
}

/// Whether reading is paused for the user's speech.
final readingDuckProvider = NotifierProvider<ReadingDuck, bool>(
  ReadingDuck.new,
);
