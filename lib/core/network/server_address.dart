import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';

/// The web app's address (the dashboard folder, without `/api/v1`). It is
/// fixed when the app is built (`--dart-define=API_BASE_URL=...`, default the
/// emulator's `http://10.0.2.2/website/percipere_dashboard`); there is no
/// setting screen for it. Every API client (accounts, books, reports,
/// health, picture description, voice models) reads this one value.
final serverAddressProvider = Provider<String>((ref) => Env.apiBaseUrl);

/// Whether a web app is configured at all.
bool hasServer(String address) => address != Env.noServer;
