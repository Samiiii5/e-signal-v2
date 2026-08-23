import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/navigation/app_router.dart';
import '../../core/services/session_service.dart';

const _closeCodeUnauthorized = 4001;
const _closeCodeStopReconnect = 4003;
const _closeCodeNormal = 1000;

class WebSocketService with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    disconnect(removeObserver: false);
    _organizationId = organizationId;
    _token = token;
    _manuallyDisconnected = false;
    _openConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('=== App resumed → vérification WebSocket ===');
      if (!_isConnected && !_manuallyDisconnected) {
        debugPrint('=== WebSocket déconnecté → reconnexion forcée ===');
        _reconnectTimer?.cancel();
        _openConnection();
      }
    }
  }

  String _maskToken(String input) {
    final token = _token;
    if (token == null || token.isEmpty) return input;
    return input.replaceAll(token, '[MASKED]');
  }

  void _openConnection() {
    if (_manuallyDisconnected || _organizationId == null || _token == null) {
      return;
    }
    try {
      final uri = Uri.parse(
        'wss://ws.score360.africa/api/v1.2/inbox/ws?organization_id=$_organizationId&token=$_token',
      );
      debugPrint(
        '=== WebSocket URI : '
        'wss://ws.score360.africa'
        '/api/v1.2/inbox/ws'
        '?organization_id=$_organizationId'
        '&token=[MASKED] ===',
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      channel.ready
          .then((_) {
            debugPrint('=== WebSocket connecté ✓ ===');
            _isConnected = true;
            _startPing();
          })
          .catchError((e) {
            debugPrint('=== WS échec type: ${e.runtimeType} ===');
            debugPrint('=== WS échec message: ${_maskToken(e.toString())} ===');
            debugPrint('=== WS closeCode: ${_channel?.closeCode} ===');
            debugPrint('=== WS closeReason: ${_channel?.closeReason} ===');
            _isConnected = false;
            _handleDisconnect();
          });

      _channelSubscription = channel.stream.listen(
        _onData,
        onError: (e) {
          debugPrint(
            '=== WebSocket stream erreur : ${_maskToken(e.toString())} ===',
          );
          _handleDisconnect();
        },
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint(
        '=== Erreur connexion WebSocket : ${_maskToken(e.toString())} ===',
      );
      _handleDisconnect();
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['event'] == 'pong') return;
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
    debugPrint('=== WS disconnect code: ${_channel?.closeCode} ===');
    debugPrint('=== WS disconnect reason: ${_channel?.closeReason} ===');
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

  void disconnect({bool removeObserver = true}) {
    if (removeObserver) {
      WidgetsBinding.instance.removeObserver(this);
    }
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