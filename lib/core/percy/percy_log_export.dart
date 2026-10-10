import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../accessibility/command_bus.dart';
import '../db/daos/percy_log_dao.dart';

/// Hands a finished CSV file to the user (the share sheet); replaced in
/// tests.
typedef CsvSharer = Future<void> Function(String path);

/// The app's CSV sharer.
final percyCsvSharerProvider = Provider<CsvSharer>(
  (ref) => (path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'Percy STT log'),
    );
  },
);

/// Hidden evaluator action: exports Percy's turn log as CSV in the dataset
/// format (`source = STT log`) and opens the share sheet.
Future<void> exportPercyLog(WidgetRef ref, CommandBus bus) async {
  final l = bus.strings;
  try {
    final entries = await ref.read(percyLogDaoProvider).all();
    if (entries.isEmpty) return await bus.say(l.percyExportEmpty);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File(p.join(dir.path, 'percy-stt-log-$stamp.csv'));
    await file.writeAsString(PercyLogDao.toCsv(entries), flush: true);
    await bus.say(l.percyExportDone);
    await ref.read(percyCsvSharerProvider)(file.path);
  } on Object catch (e, stack) {
    debugPrint('[PERCY] export failed: $e\n$stack');
    await bus.say(l.percyExportFailed);
  }
}
