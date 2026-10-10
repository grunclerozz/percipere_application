import '../accessibility/nav_intent.dart';

/// What the user wants from Percy (the classifier's labels, see
/// `data/percy/intents.csv`).
enum PercyIntent {
  /// Go to Home.
  openHome('open_home'),

  /// Open the Library (Aklatan).
  openLibrary('open_library'),

  /// Open Settings.
  openSettings('open_settings'),

  /// Back one screen.
  back('back'),

  /// Next option (Reader: next sentence).
  nextOption('next_option'),

  /// Previous option (Reader: previous sentence).
  previousOption('previous_option'),

  /// Choose the focused option.
  select('select'),

  /// Never mind (answers Percy's question like "no").
  cancel('cancel'),

  /// Help for this screen.
  help('help'),

  /// Which screen, what is focused.
  whereAmI('where_am_i'),

  /// Read the document.
  read('read'),

  /// Pause reading.
  pause('pause'),

  /// Carry on reading.
  resume('resume'),

  /// Stop speaking / reading.
  stop('stop'),

  /// Say it again.
  repeat('repeat'),

  /// Read faster.
  faster('faster'),

  /// Read slower.
  slower('slower'),

  /// Bigger text.
  biggerText('bigger_text'),

  /// Smaller text.
  smallerText('smaller_text'),

  /// Open a document by name (slot: title or ordinal).
  openItem('open_item'),

  /// Hello.
  greeting('greeting'),

  /// Thank you.
  thanks('thanks'),

  /// Goodbye: ends the session.
  goodbye('goodbye'),

  /// Yes.
  yes('yes'),

  /// No.
  no('no'),

  /// Something Percy can't do.
  outOfScope('out_of_scope');

  const PercyIntent(this.label);

  /// The label in the dataset and the model file.
  final String label;

  /// The intent for a model label, or null for an unknown one.
  static PercyIntent? fromLabel(String label) {
    for (final i in values) {
      if (i.label == label) return i;
    }
    return null;
  }

  /// The app command this intent runs through the CommandBus, if it is a
  /// plain command.
  NavIntent? get navIntent => switch (this) {
    openHome => NavIntent.home,
    openLibrary => NavIntent.library,
    openSettings => NavIntent.settings,
    back => NavIntent.back,
    nextOption => NavIntent.next,
    previousOption => NavIntent.previous,
    select => NavIntent.activate,
    help => NavIntent.help,
    read => NavIntent.read,
    pause => NavIntent.pause,
    resume => NavIntent.resume,
    stop => NavIntent.stopSpeech,
    repeat => NavIntent.repeat,
    faster => NavIntent.faster,
    slower => NavIntent.slower,
    biggerText => NavIntent.textBigger,
    smallerText => NavIntent.textSmaller,
    _ => null,
  };

  /// An answer to a yes/no question: true (yes), false (no / cancel), or
  /// null when it isn't one.
  bool? get answer => switch (this) {
    yes => true,
    no || cancel => false,
    _ => null,
  };
}
