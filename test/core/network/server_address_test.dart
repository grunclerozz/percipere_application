// The dashboard address is fixed at build time: no setting, one value for
// every API client.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/env.dart';
import 'package:percipere_app/core/network/server_address.dart';

void main() {
  test('without --dart-define=API_BASE_URL the emulator address is used', () {
    expect(Env.apiBaseUrl, 'http://10.0.2.2/website/percipere_dashboard');
    expect(Env.apiBaseUrl, Env.emulatorBaseUrl);
    expect(hasServer(Env.apiBaseUrl), isTrue);
  });

  test('every client reads the same value', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(serverAddressProvider), Env.apiBaseUrl);
  });

  test('the emulator address may use plain http (private network)', () {
    expect(Env.allowsCleartext('10.0.2.2'), isTrue);
    expect(Env.allowsCleartext('percipere.example.ph'), isFalse);
  });
}
