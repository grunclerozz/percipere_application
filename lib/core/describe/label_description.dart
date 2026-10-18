import '../../config/image_label_groups.dart';
import '../../config/image_labels_fil.dart';
import '../../l10n/app_localizations.dart';
import 'image_labeler.dart';

/// Smallest confidence a label needs to be mentioned.
const double minLabelConfidence = 0.7;

/// Confidence from which a label is stated plainly ("May plato…"); below it
/// the sentence says "Mukhang may…" (it looks like).
const double sureLabelConfidence = 0.85;

/// Most labels mentioned.
const int maxSpokenLabels = 3;

/// The same label seen more than once as one result: the counts add up and
/// the best confidence stays. Order of first appearance is kept.
List<LabelResult> _merged(List<LabelResult> all) {
  final byLabel = <String, LabelResult>{};
  for (final l in all) {
    final key = l.label.trim().toLowerCase();
    final seen = byLabel[key];
    byLabel[key] = seen == null
        ? l
        : LabelResult(
            seen.label,
            seen.confidence > l.confidence ? seen.confidence : l.confidence,
            count: seen.count + l.count,
          );
  }
  return byLabel.values.toList(growable: false);
}

/// The labels worth mentioning: confidence of at least [minLabelConfidence],
/// most confident first, a broad label ("food") dropped when a more specific
/// one of its group ("rice") is there, at most [maxSpokenLabels].
List<LabelResult> pickLabels(List<LabelResult> all) {
  final good =
      _merged(all).where((l) => l.confidence >= minLabelConfidence).toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
  final specific = {
    for (final l in good)
      if (!genericImageLabels.contains(l.label.trim().toLowerCase()))
        labelGroupOf(l.label),
  };
  return [
    for (final l in good)
      if (!genericImageLabels.contains(l.label.trim().toLowerCase()) ||
          !specific.contains(labelGroupOf(l.label)))
        l,
  ].take(maxSpokenLabels).toList(growable: false);
}

/// [english] in Filipino when [filipino] and the map knows it; otherwise the
/// English label, lowercase.
String translateLabel(String english, {required bool filipino}) {
  final key = english.trim().toLowerCase();
  return filipino ? (imageLabelsFil[key] ?? key) : key;
}

/// Whether any of [labels] suggests medicine, pills or money.
bool needsReminder(Iterable<LabelResult> labels) => labels.any(
  (l) => imageLabelReminders.contains(l.label.trim().toLowerCase()),
);

/// "a", "a at b", "a, b, at c".
String joinLabels(List<String> items, AppLocalizations l) {
  if (items.length <= 1) return items.join();
  if (items.length == 2) return '${items[0]} ${l.describeAnd} ${items[1]}';
  final head = items.sublist(0, items.length - 1).join(', ');
  return '$head, ${l.describeAnd} ${items.last}';
}

/// English plural of a lowercase label ("cup" → "cups", "glass" →
/// "glasses"); Filipino keeps the word ("2 tasa").
String _plural(String word) {
  if (RegExp(r'(s|x|z|ch|sh)$').hasMatch(word)) return '${word}es';
  if (RegExp(r'[^aeiou]y$').hasMatch(word)) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  return '${word}s';
}

/// What is said for the labels of one image, grouped: related things come
/// together (people, animals, food, …), "cup" and "mug" are not both said
/// as "tasa", and a thing seen several times is counted ("2 tasa").
/// Labels of at least [sureLabelConfidence] are stated plainly ("May pagkain
/// at plato sa larawan."); the less sure ones follow as "Mukhang may mesa
/// din.", or, when none is sure, the whole sentence is "Mukhang may…".
/// Nothing passes the threshold → the "can't tell" message. A medicine or
/// money label adds the reminder.
String offlineDescription(List<LabelResult> all, AppLocalizations l) {
  final picked = pickLabels(all);
  if (picked.isEmpty) return l.describeNothing;
  final filipino = l.localeName == 'fil';

  // Spoken order: by group, then the most confident first.
  final ordered = [...picked]
    ..sort((a, b) {
      final byGroup = labelGroupOf(a.label).index
          .compareTo(labelGroupOf(b.label).index);
      return byGroup != 0 ? byGroup : b.confidence.compareTo(a.confidence);
    });

  // One entry per spoken word: the best confidence, the larger count.
  final byName = <String, LabelResult>{};
  for (final p in ordered) {
    final name = translateLabel(p.label, filipino: filipino);
    final seen = byName[name];
    byName[name] = seen == null
        ? p
        : LabelResult(
            name,
            seen.confidence > p.confidence ? seen.confidence : p.confidence,
            count: seen.count > p.count ? seen.count : p.count,
          );
  }

  String item(String name, LabelResult r) =>
      r.count > 1 ? '${r.count} ${filipino ? name : _plural(name)}' : name;
  final sure = [
    for (final e in byName.entries)
      if (e.value.confidence >= sureLabelConfidence) item(e.key, e.value),
  ];
  final unsure = [
    for (final e in byName.entries)
      if (e.value.confidence < sureLabelConfidence) item(e.key, e.value),
  ];

  final sentence = [
    if (sure.isNotEmpty) l.describeSure(joinLabels(sure, l)),
    if (unsure.isNotEmpty)
      sure.isEmpty
          ? l.describeLooksLike(joinLabels(unsure, l))
          : l.describeAlso(joinLabels(unsure, l)),
  ].join(' ');
  return needsReminder(picked) ? '$sentence ${l.describeReminder}' : sentence;
}
