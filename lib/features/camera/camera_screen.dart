import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/algorithms/image_quality.dart';
import '../../core/extraction/document_extractor.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/platform/permissions.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/page_padding.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import '../describe/describe_controller.dart';
import '../reader/reader_controller.dart';
import '../upload/document_picker.dart';
import 'camera_guidance.dart';
import 'camera_session.dart';

/// Camera capture with audio guidance.
///
/// Full-screen preview; the whole screen is the gesture surface. Preview
/// frames are read by ML Kit and turned into calm spoken hints ("Ilapit
/// pa", "Handa na, hawakan nang maayos"). Capture by double-tap, the button,
/// saying "kunan", or automatically once the text has been clear for a
/// moment. If the in-app camera fails, offers the phone's camera app.
class CameraScreen extends ConsumerStatefulWidget {
  /// Creates the camera screen.
  const CameraScreen({
    super.key,
    this.autoCapture = true,
    this.forDescription = false,
  });

  /// Screen id.
  static const String screenId = Ids.camera;

  /// Take the photo automatically when the text is steady and clear.
  /// (Becomes a user setting in Phase 6.)
  final bool autoCapture;

  /// The photo is described (Maglarawan) instead of read.
  final bool forDescription;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraSession? _session;
  bool _live = false;
  bool _capturing = false;
  bool _starting = false;
  final GuidanceTracker _tracker = GuidanceTracker();

  /// A poor photo waiting for the answer to "kunan ulit?"; guidance and
  /// auto-capture stay quiet meanwhile.
  String? _heldPhoto;
  Timer? _heldTimer;

  /// How long a poor photo waits for an answer before the camera carries on.
  static const Duration _heldFor = Duration(seconds: 30);

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heldTimer?.cancel();
    _dropHeldPhoto();
    unawaited(_session?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released in the background and reopened after.
    if (state == AppLifecycleState.paused) {
      unawaited(_stop());
    } else if (state == AppLifecycleState.resumed && !_live && !_capturing) {
      unawaited(_start());
    }
  }

  Future<void> _stop() async {
    final s = _session;
    _session = null;
    if (mounted) setState(() => _live = false);
    await s?.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      if (!await _ensurePermission() || !mounted) return;
      final session = ref.read(cameraSessionFactoryProvider)();
      _session = session;
      _tracker.reset();
      await session.start(_onFrame).timeout(AppDurations.cameraStartLimit);
      if (mounted) setState(() => _live = true);
    } on Object catch (e) {
      debugPrint('Camera failed: $e');
      await _session?.dispose();
      _session = null;
      if (mounted) {
        await _bus.offer(_l.cameraUnavailable, _useSystemCamera);
      }
    } finally {
      _starting = false;
    }
  }

  Future<bool> _ensurePermission() async {
    final permissions = ref.read(permissionServiceProvider);
    var access = await permissions.status(AppPermission.camera);
    if (access == PermissionAccess.denied) {
      await ref
          .read(announcerProvider.notifier)
          .say(_l.cameraPermissionExplain, interrupt: false);
      access = await permissions.request(AppPermission.camera);
    }
    if (access == PermissionAccess.granted) return true;
    if (!mounted) return false;
    if (access == PermissionAccess.permanentlyDenied) {
      await _bus.offer(_l.cameraDeniedPermanent, permissions.openAppSettings);
    } else {
      await _bus.say(_l.cameraDenied);
    }
    return false;
  }

  void _onFrame(FrameStats stats) {
    if (!mounted || _capturing || _heldPhoto != null) return;
    final now = DateTime.now();
    final step = _tracker.update(Guidance.of(stats), now);
    final speak = step.speak;
    // Don't talk over the intro or a confirmation, nor over a voice
    // command being said (speaking would cancel it); the hint repeats.
    final hearing = ref.read(voiceControllerProvider).partial ?? '';
    if (speak != null &&
        !ref.read(announcerProvider).speaking &&
        hearing.trim().isEmpty) {
      _tracker.markSpoken(speak, now);
      unawaited(
        ref
            .read(announcerProvider.notifier)
            .say(speak.text(_l), screenId: CameraScreen.screenId),
      );
    }
    if (step.autoCapture &&
        widget.autoCapture &&
        ref.read(settingsProvider).autoCapture) {
      unawaited(_capture());
    }
  }

  Future<void> _capture() async {
    final session = _session;
    if (_capturing || session == null || !_live) {
      if (!_live && !_capturing) await _bus.notAvailable();
      return;
    }
    _heldTimer?.cancel();
    _dropHeldPhoto();
    setState(() => _capturing = true);
    unawaited(ref.read(hapticsProvider).confirm());
    unawaited(_bus.say(_l.cameraCapturing, protect: true));
    try {
      final path = await session.takePicture().timeout(
        AppDurations.captureLimit,
      );
      if (!mounted) return;
      final file = DocumentFile(
        path: path,
        kind: DocumentKind.image,
        fromCamera: true,
      );
      if (await _offerRetakeIfPoor(file)) return;
      if (!mounted) return;
      _openReader(file);
    } on Object catch (e) {
      debugPrint('Capture failed: $e');
      if (!mounted) return;
      setState(() => _capturing = false);
      unawaited(ref.read(hapticsProvider).error());
      await _bus.say(_l.cameraCaptureFailed);
      await _stop();
      await _start();
    }
  }

  /// Measures the photo (Laplacian variance and brightness). If it is
  /// blurry, too dark or too bright, says what to do and offers to take it
  /// again; returns true when it asked (the answer carries on from here).
  /// A failed measurement never blocks the photo.
  Future<bool> _offerRetakeIfPoor(DocumentFile file) async {
    final ImageQuality? quality;
    // A photo that is not there cannot be measured; carry on without waiting.
    if (!File(file.path).existsSync()) return false;
    try {
      final bytes = await File(file.path).readAsBytes();
      quality = await measureImageQualityAsync(bytes);
    } on Object catch (e) {
      debugPrint('[IMAGE QUALITY] check failed: $e');
      return false;
    }
    debugPrint('[IMAGE QUALITY] $quality');
    final issue = quality?.issue;
    if (issue == null || !mounted) return false;
    final l = _l;
    final tip = switch (issue) {
      ImageIssue.blurry => l.qualityBlurry,
      ImageIssue.tooDark => l.qualityTooDark,
      ImageIssue.tooBright => l.qualityTooBright,
    };
    _dropHeldPhoto();
    _heldPhoto = file.path;
    _heldTimer?.cancel();
    _heldTimer = Timer(_heldFor, _dropHeldPhoto);
    _tracker.reset();
    setState(() => _capturing = false);
    unawaited(ref.read(hapticsProvider).error());
    await _bus.offer(
      '$tip ${l.qualityRetake}',
      () async {
        _dropHeldPhoto();
        await _bus.say(_l.qualityRetaking);
      },
      onDecline: () {
        if (_heldPhoto != file.path) return;
        _heldPhoto = null;
        _heldTimer?.cancel();
        if (mounted) _openReader(file);
      },
    );
    return true;
  }

  /// Forgets the photo waiting for an answer and deletes its file.
  void _dropHeldPhoto() {
    final path = _heldPhoto;
    _heldPhoto = null;
    if (path == null) return;
    unawaited(File(path).delete().then((_) {}).catchError((_) {}));
  }

  Future<void> _useSystemCamera() async {
    final result = await ref
        .read(documentPickerProvider)
        .takePhotoWithSystemCamera();
    if (!mounted) return;
    switch (result) {
      case Picked(:final file):
        _openReader(file);
      case PickFailed():
        await _bus.say(_bus.strings.uploadFailed);
      case PickCancelled() || PickUnsupported():
        break;
    }
  }

  void _openReader(DocumentFile file) {
    if (widget.forDescription) {
      ref
          .read(routerProvider)
          .pushReplacement(
            AppRoutes.describe,
            extra: NewImage(file.path, fromCamera: file.fromCamera),
          );
      return;
    }
    // Replace the camera: "back" from the Reader returns to Capture.
    ref
        .read(routerProvider)
        .pushReplacement(AppRoutes.reader, extra: FileSource(file));
  }

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: CameraScreen.screenId,
    title: (l) => l.screenCamera,
    prompt: (l) => l.cameraIntro,
    listOptions: false,
    includeModeHint: false,
    help: (l) => l.helpCamera,
    actions: [
      A11yAction(
        id: Ids.cameraCapture,
        label: (l) => l.cameraCaptureButton,
        voiceSynonyms: const ['kunan', 'capture', 'litrato', 'picture'],
        // The capture itself says "Kinukunan na."
        confirmation: (_) => '',
        onActivate: (_) => _capture(),
      ),
    ],
    intentHandlers: {
      NavIntent.activate: (bus) => bus.activate(Ids.cameraCapture),
      NavIntent.capture: (bus) => bus.activate(Ids.cameraCapture),
      NavIntent.camera: (bus) => bus.activate(Ids.cameraCapture),
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.palette;
    final session = _session;

    return AccessibleScreen(
      registration: _registration,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureSurface(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: _live && session != null
                    ? Center(child: session.preview())
                    : const SizedBox.expand(),
              ),
              SafeArea(
                child: PagePadding(
                  top: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.background.withValues(alpha: 0.9),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppDimens.panelRadius),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: LiveSpeakingZone(
                            screenId: CameraScreen.screenId,
                            fallback: l10n.screenCamera,
                          ),
                        ),
                      ),
                      const Spacer(),
                      PillButton(
                        label: l10n.cameraCaptureButton,
                        onPressed: _capturing
                            ? null
                            : () => ref
                                  .read(commandBusProvider)
                                  .activate(Ids.cameraCapture),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
