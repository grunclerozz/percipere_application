/// Finding the dashboard on the local Wi-Fi when its saved address stops
/// answering (`lib/core/network/server_discovery.dart`).
abstract final class DiscoveryConfig {
  /// The dashboard folder on the PC (XAMPP).
  static const String folder = '/website/percipere_dashboard';

  /// Ports tried on every address of the subnet, in this order.
  static const List<int> ports = [80, 8888];

  /// First host number of the subnet that is tried.
  static const int firstHost = 1;

  /// Last host number of the subnet that is tried.
  static const int lastHost = 254;

  /// Requests in flight at once (fewer would not fit the time; many more
  /// would load the tablet's network stack).
  static const int parallel = 96;

  /// Longest wait for one address.
  static const Duration probeTimeout = Duration(milliseconds: 900);

  /// Longest time for the whole scan.
  static const Duration budget = Duration(seconds: 5);

  /// After a search found nothing, the next one waits at least this long
  /// (an API call that can't reach the server would otherwise start one each).
  static const Duration cooldown = Duration(seconds: 30);
}
