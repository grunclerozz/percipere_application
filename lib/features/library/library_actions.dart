import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/library/library_models.dart';
import '../../core/library/library_service.dart';
import '../../core/tts/speech_language.dart';
import '../../l10n/app_localizations.dart';
import '../describe/describe_controller.dart';
import '../reader/reader_controller.dart';

/// What can be done with a library item: read it (fetching books first),
/// download it, mark it finished. Shared by the Library and the details
/// screen so both speak and behave the same.
class LibraryActions {
  /// Creates the actions.
  LibraryActions(this._ref);

  final Ref _ref;

  AppLocalizations get _l => _ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => _ref.read(commandBusProvider);
  LibraryDao get _dao => _ref.read(libraryDaoProvider);
  LibraryService get _service => _ref.read(libraryServiceProvider);

  /// Opens [item] in the Reader (or the Description screen for a saved
  /// Maglarawan). A book that is not on the phone is fetched first, with
  /// spoken progress. With [fromStart] the saved position is ignored.
  Future<void> open(LibraryItem item, {bool fromStart = false}) async {
    final router = _ref.read(routerProvider);
    if (item.source == LibrarySource.description) {
      unawaited(
        router.push(AppRoutes.describe, extra: SavedDescription(item.id)),
      );
      return;
    }
    if (item.isBook) {
      final ok = await _prepare(item);
      if (!ok) return;
    }
    unawaited(
      router.push(
        AppRoutes.reader,
        extra: ItemSource(item.id, fromStart: fromStart),
      ),
    );
  }

  /// Makes a book's text ready, speaking progress and problems. False if it
  /// cannot be read now.
  Future<bool> _prepare(LibraryItem item) async {
    final l = _l;
    final announcer = _ref.read(announcerProvider.notifier);
    if (item.unavailable && !item.downloaded) {
      await _problem(l.bookUnavailable(item.title));
      return false;
    }
    var spoken = -1;
    var started = false;
    final result = await _service.prepareToRead(
      item,
      onProgress: (fraction) {
        if (!started) {
          started = true;
          unawaited(announcer.say(l.bookLoading, interrupt: false));
        }
        if (fraction == null) return;
        final step = (fraction * 4).floor(); // 25 % steps
        if (step > spoken && {1, 2, 3}.contains(step)) {
          spoken = step;
          unawaited(
            announcer.say(l.bookLoadingPercent(step * 25), interrupt: false),
          );
        }
      },
    );
    return _report(result, item, l);
  }

  Future<bool> _report(
    BookResult result,
    LibraryItem item,
    AppLocalizations l,
  ) async {
    switch (result) {
      case BookResult.ready:
        return true;
      case BookResult.offline:
        await _problem(l.libraryNeedsInternet);
      case BookResult.unavailable:
        await _problem(l.bookUnavailable(item.title));
      case BookResult.drm:
        await _problem(l.bookDrm);
      case BookResult.invalid:
        await _problem(l.bookInvalid);
      case BookResult.passwordProtected:
        await _problem(l.readerPasswordProtected);
      case BookResult.empty:
        await _problem(l.bookEmpty);
      case BookResult.lowStorage:
      case BookResult.failed:
        await _problem(l.bookFailed);
    }
    return false;
  }

  Future<void> _problem(String text) async {
    unawaited(_ref.read(hapticsProvider).error());
    await _bus.say(text);
  }

  /// Downloads a book for offline reading. The first time a guest does it,
  /// recommends registering; declining carries on. Warns about low storage.
  /// Returns whether the book is now downloaded.
  Future<bool> download(LibraryItem item, {bool update = false}) async {
    final l = _l;
    final account = _ref.read(currentAccountProvider);
    if (account != null && account.isGuest && !update) {
      final prefs = _ref.read(userPrefsProvider);
      final count = await prefs.get(
        PrefKeys.guestReminderDownload,
        userId: account.id,
      );
      if (count is! int || count < 1) {
        await prefs.set(PrefKeys.guestReminderDownload, 1, userId: account.id);
        final registers = Completer<bool>();
        unawaited(
          _bus.offer(l.guestDownloadWarning, () {
            registers.complete(true);
            unawaited(_ref.read(routerProvider).push(AppRoutes.register));
          }, onDecline: () => registers.complete(false)),
        );
        // Accepting leaves for registration; the download waits for later.
        if (await registers.future) return false;
      }
    }
    return _download(item, l);
  }

  Future<bool> _download(
    LibraryItem item,
    AppLocalizations l, {
    bool ignoreLowStorage = false,
  }) async {
    final announcer = _ref.read(announcerProvider.notifier);
    var spoken = -1;
    var started = false;
    final result = await _service.download(
      item,
      ignoreLowStorage: ignoreLowStorage,
      onProgress: (fraction) {
        if (!started) {
          started = true;
          unawaited(announcer.say(l.bookLoading, interrupt: false));
        }
        if (fraction == null) return;
        final step = (fraction * 4).floor();
        if (step > spoken && {1, 2, 3}.contains(step)) {
          spoken = step;
          unawaited(
            announcer.say(l.bookLoadingPercent(step * 25), interrupt: false),
          );
        }
      },
    );
    if (result == BookResult.lowStorage) {
      final completer = Completer<bool>();
      unawaited(
        _bus.offer(
          l.downloadLowStorage(sizeLabel(item.fileSize ?? 0, l)),
          () => completer.complete(true),
          onDecline: () => completer.complete(false),
        ),
      );
      if (!await completer.future) return false;
      return _download(item, l, ignoreLowStorage: true);
    }
    if (!await _report(result, item, l)) return false;
    unawaited(_ref.read(hapticsProvider).confirm());
    await _bus.say(l.downloadDone(item.title));
    return true;
  }

  /// Deletes the downloaded copy, keeping progress and favorites.
  Future<void> removeDownload(LibraryItem item) async {
    await _service.removeDownload(item);
    unawaited(_ref.read(hapticsProvider).confirm());
    await _bus.say(_l.downloadRemoved(item.title));
  }

  /// Marks [item] finished or not.
  Future<void> setFinished(LibraryItem item, {required bool finished}) async {
    await _dao.setFinished(item.id, finished: finished);
    unawaited(_ref.read(hapticsProvider).confirm());
    await _bus.say(
      finished
          ? _l.markedFinished(item.title)
          : _l.markedUnfinished(item.title),
    );
  }

  /// Offers to update a downloaded book whose version changed, keeping the
  /// reading position. Returns true if the update was accepted and finished.
  Future<void> offerUpdate(LibraryItem item) async {
    final l = _l;
    unawaited(
      _bus.offer(l.bookUpdateOffer(item.title), () async {
        final fresh = await _dao.get(item.id) ?? item;
        if (await _download(fresh, l)) {
          await _bus.say(l.bookUpdated(item.title));
        }
      }),
    );
  }

  /// "3.2 MB" / "512 KB" for [bytes].
  static String sizeLabel(int bytes, AppLocalizations l) {
    if (bytes >= 1024 * 1024) {
      return l.sizeMegabytes((bytes / (1024 * 1024)).toStringAsFixed(1));
    }
    return l.sizeKilobytes(((bytes / 1024).ceil()).toString());
  }

  /// "kahapon", "ngayon", "3 araw na ang nakalipas" or a date.
  static String whenLabel(DateTime when, AppLocalizations l, [DateTime? now]) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final days = today.difference(DateUtils.dateOnly(when)).inDays;
    if (days <= 0) return l.whenToday;
    if (days == 1) return l.whenYesterday;
    if (days < 14) return l.whenDaysAgo(days);
    return DateFormat.yMMMd(l.localeName).format(when);
  }
}

/// The Library's item actions.
final libraryActionsProvider = Provider<LibraryActions>(LibraryActions.new);
