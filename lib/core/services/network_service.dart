import 'dart:async';
import 'dart:io';

/// Vérifie la connectivité réseau toutes les 5 secondes via DNS lookup.
/// Fonctionne sur iOS et Android uniquement (dart:io).
class NetworkService {
  NetworkService._();

  static final _controller = StreamController<bool>.broadcast();
  static bool _isOnline = true;
  static Timer? _timer;

  static Stream<bool> get onStatusChange => _controller.stream;
  static bool get isOnline => _isOnline;

  static void startMonitoring() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _check() async {
    bool online;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
    }
  }
}
