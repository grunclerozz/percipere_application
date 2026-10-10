// Percy's settings: ElevenLabs is off by default and only a developer build
// shows its switch; the turn log exports in the dataset's CSV format.

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/ids.dart';
import 'package:percipere_app/config/env.dart';
import 'package:percipere_app/core/db/daos/percy_log_dao.dart';
import 'package:percipere_app/core/percy/percy_responses.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/features/settings/setting_items.dart';

void main() {
  test('ElevenLabs is off by default; local Percy defaults', () {
    const s = AppSettings();
    expect(s.percyElevenLabs, isFalse);
    expect(s.percyLogging, isTrue);
    expect(s.percyPoliteness, PercyPoliteness.po);
    expect(s.percyTalk, PercyTalk.normal);
    // Missing or unknown stored values keep the safe default.
    expect(AppSettings.fromPrefs(const {}).percyElevenLabs, isFalse);
    expect(
      AppSettings.fromPrefs(const {'percy.elevenLabs': 'yes'}).percyElevenLabs,
      isFalse,
    );
  });

  test('Percy settings are saved and read back', () {
    final s = const AppSettings().copyWith(
      percyPoliteness: PercyPoliteness.casual,
      percyTalk: PercyTalk.chatty,
      percyLogging: false,
      percyElevenLabs: true,
    );
    expect(AppSettings.fromPrefs(s.toPrefs()), s);
  });

  test('only developer builds show the ElevenLabs switch and the export', () {
    final ids = [for (final i in settingItemsFor(null)) i.id];
    expect(ids, contains(Ids.settingPercyPoliteness));
    expect(ids, contains(Ids.settingPercyTalk));
    expect(ids, contains(Ids.settingPercyLogging));
    expect(Env.devTools, isFalse); // tests run as a normal build
    expect(ids, isNot(contains(Ids.settingPercyElevenLabs)));
    expect(ids, isNot(contains(Ids.settingPercyExport)));
  });

  test('log export: dataset columns, source "STT log", quoting', () {
    final csv = PercyLogDao.toCsv([
      PercyLogEntry(
        text: 'buksan mo, "yung" bill',
        intent: 'open_item',
        confidence: 0.4567,
        outcome: 'asked',
        screen: 'home',
        modelVersion: 'v1',
        at: DateTime(2026, 10, 10, 9),
      ),
      PercyLogEntry(
        text: 'kumanta ka',
        outcome: 'fallback',
        at: DateTime(2026, 10, 10, 9, 1),
      ),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'text,intent,author,source,notes');
    expect(
      lines[1],
      '"buksan mo, ""yung"" bill",open_item,,STT log,outcome=asked; '
      'confidence=0.46; screen=home; model=v1; date=2026-10-10T09:00:00.000',
    );
    expect(lines[2], startsWith('kumanta ka,,,STT log,outcome=fallback'));
  });
}
