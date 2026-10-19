import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../network/image_description_repository.dart';
import '../settings/app_settings.dart';
import '../settings/settings_controller.dart';
import 'image_labeler.dart';
import 'image_prep.dart';
import 'label_description.dart';
import 'object_counting.dart';
import 'object_detector.dart';
import 'vision_availability.dart';

/// What a describer said about one picture.
@immutable
class ImageDescription {
  /// Creates a description.
  const ImageDescription(
    this.text, {
    this.labels = const [],
    this.online = false,
  });

  /// The sentence(s) to show and speak, in the language asked for.
  final String text;

  /// What the picture was found to contain (empty when the describer has no
  /// labels, e.g. an online one).
  final List<LabelResult> labels;

  /// Whether the server (Gemini) described it, not the phone (ML Kit).
  final bool online;
}

/// Turns a picture into a spoken description. The Maglarawan screen only
/// knows this interface: [MlKitImageDescriber] works on the phone and
/// [OnlineImageDescriber] asks the server first.
abstract interface class ImageDescriber {
  /// Describes the image at [path] in the language of [strings]. Throws when
  /// the image can't be read.
  Future<ImageDescription> describe(String path, AppLocalizations strings);

  /// Frees native resources.
  Future<void> close();
}

/// The offline describer: ML Kit's image labels, grouped and worded with
/// "Mukhang…" when unsure ([offlineDescription]), plus how many objects ML Kit
/// found and where ([countingPhrase]). Works without internet and sends
/// nothing anywhere.
class MlKitImageDescriber implements ImageDescriber {
  /// Describes with [_labeler]; counts objects with [objectDetector] when
  /// there is one.
  MlKitImageDescriber(this._labeler, {ObjectDetectorService? objectDetector})
    : _objects = objectDetector;

  final ImageLabelerService _labeler;
  final ObjectDetectorService? _objects;

  @override
  Future<ImageDescription> describe(
    String path,
    AppLocalizations strings,
  ) async {
    final labels = await _labeler.label(path);
    var text = offlineDescription(labels, strings);
    final counting = await _counting(path, labels, strings);
    if (counting != null) text = '$text $counting';
    return ImageDescription(text, labels: labels);
  }

  /// The counting sentence; null when the detector fails or finds nothing
  /// (the labels alone are still a description).
  Future<String?> _counting(
    String path,
    List<LabelResult> labels,
    AppLocalizations strings,
  ) async {
    final detector = _objects;
    if (detector == null) return null;
    try {
      return countingPhrase(await detector.detect(path), labels, strings);
    } on Object catch (e) {
      debugPrint('Object detection failed: $e');
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _labeler.close();
    await _objects?.close();
  }
}

/// Online first, ML Kit as the fallback. When the user agreed to send
/// pictures ([consent]) and the server says it can describe them
/// ([availability]), the picture goes to `POST /api/v1/describe`; on any
/// error, timeout, 429, 503 or missing internet the [fallback] describes it
/// at once, with no error message.
class OnlineImageDescriber implements ImageDescriber {
  /// Creates the describer. [timeout] bounds the server request.
  OnlineImageDescriber({
    required this.fallback,
    required this.repository,
    required this.availability,
    required this.prep,
    required this.consent,
    this.timeout = const Duration(seconds: 8),
  });

  /// Describes when the server can't (the phone's own ML Kit).
  final ImageDescriber fallback;

  /// Talks to the server.
  final ImageDescriptionRepository repository;

  /// Says whether the server can describe pictures now.
  final VisionAvailability availability;

  /// Shrinks the picture before it is sent.
  final ImagePrep prep;

  /// Whether the user agreed to send pictures.
  final bool Function() consent;

  /// How long the server gets to answer.
  final Duration timeout;

  @override
  Future<ImageDescription> describe(
    String path,
    AppLocalizations strings,
  ) async {
    if (consent() && await availability.check()) {
      try {
        final jpeg = await prep.forUpload(path);
        if (jpeg != null) {
          final result = await repository
              .describe(
                jpeg: jpeg,
                language: strings.localeName == 'fil' ? 'fil' : 'en',
              )
              .timeout(timeout);
          return ImageDescription(result.description, online: true);
        }
      } on Object catch (e) {
        debugPrint('[DESCRIBE] online failed, using ML Kit: $e');
      }
    }
    return fallback.describe(path, strings);
  }

  @override
  Future<void> close() => fallback.close();
}

/// The describer Maglarawan uses: online first, ML Kit as the fallback.
final imageDescriberProvider = Provider<ImageDescriber>(
  (ref) => OnlineImageDescriber(
    fallback: MlKitImageDescriber(
      ref.watch(imageLabelerProvider),
      objectDetector: ref.watch(objectDetectorProvider),
    ),
    repository: ref.watch(imageDescriptionRepositoryProvider),
    availability: ref.watch(visionAvailabilityProvider),
    prep: ref.watch(imagePrepProvider),
    consent: () =>
        ref.read(settingsProvider).describeConsent == DescribeConsent.allowed,
  ),
);
