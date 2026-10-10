import '../../config/percy_config.dart';
import '../library/library_models.dart';
import '../library/library_view.dart';
import '../voice/understanding.dart';
import 'percy_text.dart';

/// Rule-based slot extraction for Percy (`open_item`): which document the
/// user means, by title or by position ("yung pangalawa").
abstract final class PercySlots {
  /// Ordinal words → position (−1 = the last one).
  static const Map<String, int> ordinals = {
    'una': 0, 'unang': 0, 'first': 0, 'isa': 0, //
    'pangalawa': 1, 'ikalawa': 1, 'second': 1, 'dalawa': 1, //
    'pangatlo': 2, 'ikatlo': 2, 'third': 2, 'tatlo': 2, //
    'huli': -1, 'huling': -1, 'last': -1,
  };

  /// Words that never belong to a title (commands, fillers, articles).
  static const Set<String> _notTitle = {
    // verbs and polite forms
    'buksan', 'bukas', 'pakibukas', 'pakibuksan', 'open', 'basahin', 'basa',
    'pakibasa', 'babasahin', 'read', 'ituloy', 'continue', 'resume',
    'gusto', 'kong', 'ko', 'gustong', 'nais', 'want', 'to', 'i', 'please',
    'pwede', 'puwede', 'bang', 'ba', 'can', 'you', 'mo', 'nga', 'po',
    'naman', 'lang', 'na', 'yung', 'iyong', 'ung', 'ang', 'ng', 'sa', 'the',
    'my', 'aking', 'a', 'an', 'si', 'kay', 'muna', 'show', 'me', 'ipakita',
    'dokumento', 'document', 'file', 'may', 'ako', 'akong', 'bubuksan',
    'something', 'mga', 'isang', 'one',
  };

  /// The ordinal said in [text] ("yung pangalawa", "number 2", "the last
  /// one"), or null. 1-based digits are turned 0-based.
  static int? ordinal(String text) {
    final words = PercyText.preprocess(text).split(' ');
    for (final w in words) {
      final o = ordinals[w];
      if (o != null) return o;
      final n = int.tryParse(w);
      if (n != null && n >= 1 && n <= 9) return n - 1;
    }
    return null;
  }

  /// The words of [text] that could be a title ("buksan mo yung Liham kay
  /// Nanay" → "liham kay nanay"); empty when only command words were said.
  static String titleWords(String text) {
    final cmd = Understanding.titleCommand(text);
    final source = cmd?.title ?? text;
    final words = PercyText.preprocess(source)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    // Drop command words at the edges only ("liham kay nanay" keeps "kay").
    while (words.isNotEmpty && _notTitle.contains(words.first)) {
      words.removeAt(0);
    }
    while (words.isNotEmpty && _notTitle.contains(words.last)) {
      words.removeLast();
    }
    return words.join(' ');
  }

  /// Items whose title fits [title] at [PercyConfig.titleMatch] or better,
  /// best first.
  static List<LibraryItem> matchTitle(List<LibraryItem> items, String title) {
    if (title.trim().isEmpty) return const [];
    return [
      for (final r in LibraryView.rankByTitle(
        items,
        title,
        floor: PercyConfig.titleMatch,
      ))
        r.item,
    ];
  }

  /// The item at [ordinal] in [items] (−1 = last), or null.
  static T? at<T>(List<T> items, int ordinal) {
    if (items.isEmpty) return null;
    final i = ordinal < 0 ? items.length + ordinal : ordinal;
    return i >= 0 && i < items.length ? items[i] : null;
  }
}
