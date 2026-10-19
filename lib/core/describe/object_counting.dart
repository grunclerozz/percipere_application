import '../../config/count_words.dart';
import '../../config/image_label_groups.dart';
import '../../l10n/app_localizations.dart';
import 'image_labeler.dart';
import 'label_description.dart';
import 'object_detector.dart';

/// English article for [word].
String _article(String word) =>
    RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(word) ? 'an' : 'a';

/// The names to give the counted objects: the best image labels, without
/// scenery (sky, sea, …), one per spoken word, at most [count].
List<LabelResult> _namesFor(
  List<LabelResult> labels,
  int count,
  bool filipino,
) {
  final seen = <String>{};
  final names = <LabelResult>[];
  for (final l in pickLabels(labels)) {
    if (labelGroupOf(l.label) == LabelGroup.nature) continue;
    if (seen.add(translateLabel(l.label, filipino: filipino))) names.add(l);
  }
  return names.take(count).toList(growable: false);
}

/// The sentence about how many objects there are, what they are where
/// possible, and where they are: "May tatlong bagay: isang tasa, isang
/// libro, at isang bote. Isa sa kaliwa, dalawa sa gitna."
///
/// [objects] are what the object detector found (the count and the
/// positions); [labels] are the image labels (the names). The sentence is
/// stated plainly only when every object has a confident name; otherwise it
/// starts "Mukhang may…" with "mga" before the names, and with no names at
/// all it only says how many. Null when no object was found.
String? countingPhrase(
  List<FoundObject> objects,
  List<LabelResult> labels,
  AppLocalizations l,
) {
  if (objects.isEmpty) return null;
  final filipino = l.localeName == 'fil';
  final n = objects.length;
  final count = countWordBeforeNoun(n, filipino: filipino);

  final names = _namesFor(labels, n, filipino);
  final sure =
      names.length == n &&
      names.every((r) => r.confidence >= sureLabelConfidence);
  final String head;
  if (names.isEmpty) {
    head = l.describeCountOnly(n, count);
  } else {
    final words = [
      for (final r in names) translateLabel(r.label, filipino: filipino),
    ];
    final items = joinLabels([
      for (final w in words)
        sure
            ? l.describeCountItem(w, _article(w))
            : l.describeCountItemUnsure(w, _article(w)),
    ], l);
    head = sure
        ? l.describeCountSure(n, count, items)
        : l.describeCountUnsure(n, count, items);
  }

  final perSide = {
    for (final side in ObjectSide.values)
      side: objects.where((o) => o.side == side).length,
  };
  String where(ObjectSide side) {
    final words = countWord(perSide[side]!, filipino: filipino);
    return switch (side) {
      ObjectSide.left => l.describeCountLeft(words),
      ObjectSide.middle => l.describeCountMiddle(words),
      ObjectSide.right => l.describeCountRight(words),
    };
  }

  final position = joinLabels([
    for (final side in ObjectSide.values)
      if (perSide[side]! > 0) where(side),
  ], l);
  final capitalised = position[0].toUpperCase() + position.substring(1);
  return '$head $capitalised.';
}
