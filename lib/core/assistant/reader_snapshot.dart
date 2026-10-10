import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the Reader shows right now, for the voice assistant (where the user
/// is in the document, and its text for questions or a summary).
@immutable
class ReaderSnapshot {
  /// Creates a snapshot.
  const ReaderSnapshot({
    required this.title,
    required this.text,
    required this.sentence,
    required this.sentenceCount,
    required this.playing,
    required this.canRead,
  });

  /// Document title, if saved.
  final String? title;

  /// Clean document text.
  final String text;

  /// Current sentence (0-based).
  final int sentence;

  /// Sentences in the document.
  final int sentenceCount;

  /// Being read aloud now.
  final bool playing;

  /// Text is ready to be read.
  final bool canRead;
}

/// The open Reader's snapshot (null when no Reader is open). Written by the
/// Reader screen.
class ReaderSnapshotNotifier extends Notifier<ReaderSnapshot?> {
  @override
  ReaderSnapshot? build() => null;

  /// Sets or clears (null) the snapshot.
  void set(ReaderSnapshot? snapshot) {
    if (ref.mounted) state = snapshot;
  }

  /// Clears the snapshot if it is still [snapshot] (a Reader closing must
  /// not clear a newer Reader's snapshot).
  void clearIf(ReaderSnapshot? snapshot) {
    if (ref.mounted && identical(state, snapshot)) state = null;
  }
}

/// The open Reader, if any.
final readerSnapshotProvider =
    NotifierProvider<ReaderSnapshotNotifier, ReaderSnapshot?>(
      ReaderSnapshotNotifier.new,
    );
