import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'image_labeler.dart';
import 'label_description.dart';

/// What a describer said about one picture.
@immutable
class ImageDescription {
  /// Creates a description.
  const ImageDescription(this.text, {this.labels = const []});

  /// The sentence(s) to show and speak, in the language asked for.
  final String text;

  /// What the picture was found to contain (empty when the describer has no
  /// labels, e.g. an online one).
  final List<LabelResult> labels;
}

/// Turns a picture into a spoken description. The Maglarawan screen only
/// knows this interface: [MlKitImageDescriber] works on the phone, and an
/// online describer (the dashboard's detailed description) can be added
/// behind the same interface later without touching the screen.
abstract interface class ImageDescriber {
  /// Describes the image at [path] in the language of [strings]. Throws when
  /// the image can't be read.
  Future<ImageDescription> describe(String path, AppLocalizations strings);

  /// Frees native resources.
  Future<void> close();
}

/// The offline describer: ML Kit's image labels, grouped and worded with
/// "Mukhang…" when unsure ([offlineDescription]). Works without internet and
/// sends nothing anywhere.
class MlKitImageDescriber implements ImageDescriber {
  /// Describes with [labeler].
  MlKitImageDescriber(this._labeler);

  final ImageLabelerService _labeler;

  @override
  Future<ImageDescription> describe(
    String path,
    AppLocalizations strings,
  ) async {
    final labels = await _labeler.label(path);
    return ImageDescription(
      offlineDescription(labels, strings),
      labels: labels,
    );
  }

  @override
  Future<void> close() => _labeler.close();
}

/// The describer Maglarawan uses first (always offline).
final imageDescriberProvider = Provider<ImageDescriber>(
  (ref) => MlKitImageDescriber(ref.watch(imageLabelerProvider)),
);
