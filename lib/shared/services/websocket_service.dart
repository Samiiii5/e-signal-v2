import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/navigation/app_router.dart';
import '../../core/services/session_service.dart';

/// Codes de fermeture WebSocket ayant un sens applicatif particulier.
/// - 4001 : session invalide côté serveur → déconnexion forcée de l'utilisateur.
/// - 4003 : le serveur demande explicitement d'arrêter de se reconnecter.
/// - 1000 : fermeture propre (normale) → pas de reconnexion.
const _closeCodeUnauthorized = 4001;
const _closeCodeStopReconnect = 4003;
const _closeCodeNormal = 1000;

/// Connexion temps réel à l'inbox.
///
/// wss://ws.score360.africa/api/v1.2/inbox/ws?organization_id={uuid}&token={jwt}
/// Le token part sans le préfixe "Bearer " — juste la valeur du JWT.
///
/// Émet chaque message JSON reçu tel quel sur [events] (sauf "pong", qui ne
/// sert qu'au keepalive) ; c'est à chaque écran (InboxScreen, ChatScreen)
/// de filtrer les événements qui le concernent.
class WebSocketService {
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();

  String? _organizationId;
  String? _token;
  bool _isConnected = false;
  bool _manuallyDisconnected = true;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  bool get isConnected => _isConnected;

  void connect({required String organizationId, required String token}) {
    disconnect();
    _organizationId = organizationId;
    _token = token;
    _manuallyDisconnected = false;
    _openConnection();
  }

  void _openConnection() {
    if (_manuallyDisconnected || _organizationId == null || _token == null) return;
    try {
      // Port 443 explicite : web_socket_channel v3 convertit wss:// → https://
      // via uri.replace(scheme:'https'). Sans port explicite, uri.port retourne 0
      // en Dart (pas de port par défaut pour wss), ce qui produit https://host:0/...
      // et la connexion échoue. Avec port:443, la conversion donne https://host:443/
      // que Dart omet en sérialisation (port = défaut https) → URL propre.
      final uri = Uri(
        scheme: 'wss',
        host: 'ws.score360.africa',
        port: 443,
        path: '/api/v1.2/inbox/ws',
        queryParameters: {
          'organization_id': _organizationId!,
          'token': _token!,
        },
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _isConnected = true;
      _channelSubscription = channel.stream.listen(
        _onData,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
      _startPing();
    } catch (e) {
      debugPrint('=== Erreur connexion WebSocket : $e ===');
      _handleDisconnect();
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['event'] == 'pong') return; // keepalive — rien à faire
      _eventsController.add(decoded);
    } catch (e) {
      debugPrint('=== Erreur parsing message WebSocket : $e ===');
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      try {
        _channel?.sink.add('ping');
      } catch (e) {
        debugPrint('=== Erreur ping WebSocket : $e ===');
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _channelSubscription?.cancel();

    final code = _channel?.closeCode;
    if (code == _closeCodeUnauthorized) {
      _manuallyDisconnected = true;
      _forceLogout();
      return;
    }
    if (code == _closeCodeStopReconnect || code == _closeCodeNormal) {
      _manuallyDisconnected = true;
      return;
    }

    if (_manuallyDisconnected) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _openConnection);
  }

  void _forceLogout() {
    SessionService.logout();
    final context = navigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go('/login');
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}

final webSocketService = WebSocketService();
