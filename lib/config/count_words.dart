/// Number words for the spoken object count ("May tatlong bagay", "one on the
/// left"). Numbers above [maxCountWord] are said as digits.
const int maxCountWord = 10;

const List<String> _filPlain = [
  'isa', 'dalawa', 'tatlo', 'apat', 'lima', 'anim', 'pito', 'walo', //
  'siyam', 'sampu',
];

// The form that goes before a noun ("tatlong bagay", "apat na bagay").
const List<String> _filLinked = [
  'isang', 'dalawang', 'tatlong', 'apat na', 'limang', 'anim na', 'pitong', //
  'walong', 'siyam na', 'sampung',
];

const List<String> _enPlain = [
  'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', //
  'ten',
];

/// [n] as a word on its own ("tatlo", "three"); digits above [maxCountWord].
String countWord(int n, {required bool filipino}) {
  if (n < 1 || n > maxCountWord) return '$n';
  return (filipino ? _filPlain : _enPlain)[n - 1];
}

/// [n] as the Filipino word that goes before a noun ("tatlong", "apat na");
/// digits with "na" above [maxCountWord]. English needs no linking: the
/// plain word.
String countWordBeforeNoun(int n, {required bool filipino}) {
  if (!filipino) return countWord(n, filipino: false);
  if (n < 1) return '$n';
  return n > maxCountWord ? '$n na' : _filLinked[n - 1];
}
