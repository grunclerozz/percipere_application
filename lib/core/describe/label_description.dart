import '../../config/image_labels_fil.dart';
import '../../l10n/app_localizations.dart';
import 'image_labeler.dart';

/// Smallest confidence a label needs to be mentioned.
const double minLabelConfidence = 0.7;

/// Most labels mentioned.
const int maxSpokenLabels = 3;

/// The labels worth mentioning: confidence of at least [minLabelConfidence],
/// most confident first, at most [maxSpokenLabels].
List<LabelResult> pickLabels(List<LabelResult> all) {
  final good = all.where((l) => l.confidence >= minLabelConfidence).toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  return good.take(maxSpokenLabels).toList(growable: false);
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

/// What is said for the labels of one image, always starting "Mukhang…" /
/// "It looks like…" (it is an estimate). Nothing passes the threshold → the
/// "can't tell" message. A medicine or money label adds the reminder.
String offlineDescription(List<LabelResult> all, AppLocalizations l) {
  final picked = pickLabels(all);
  if (picked.isEmpty) return l.describeNothing;
  final filipino = l.localeName == 'fil';
  final items = [
    for (final p in picked) translateLabel(p.label, filipino: filipino),
  ];
  final sentence = l.describeLooksLike(joinLabels(items, l));
  return needsReminder(picked) ? '$sentence ${l.describeReminder}' : sentence;
}
