import 'dart:async';
import '../logging/app_logger.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants/app_constants.dart';

enum SignalRConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class SignalRClient {
  final AppLogger _logger;
  late HubConnection _hubConnection;

  final _connectionStateController =
      StreamController<SignalRConnectionState>.broadcast();
  Stream<SignalRConnectionState> get connectionState =>
      _connectionStateController.stream;

  SignalRConnectionState _currentState = SignalRConnectionState.disconnected;
  SignalRConnectionState get currentState => _currentState;

  SignalRClient({required String baseUrl, AppLogger? logger})
      : _logger = logger ?? AppLogger('SignalR') {
    final serverUrl = '$baseUrl${AppConstants.kSignalRHubPath}';

    _hubConnection = HubConnectionBuilder()
        .withUrl(serverUrl)
        .withAutomaticReconnect(retryDelays: AppConstants.kReconnectDelaysMs)
        .build();

    _hubConnection.onclose(({error}) {
      _updateState(SignalRConnectionState.disconnected);
      _logger.w('SignalR connection closed: $error');
    });

    _hubConnection.onreconnecting(({error}) {
      _updateState(SignalRConnectionState.reconnecting);
      _logger.i('SignalR reconnecting: $error');
    });

    _hubConnection.onreconnected(({connectionId}) {
      _updateState(SignalRConnectionState.connected);
      _logger.i('SignalR reconnected: $connectionId');
    });
  }

  Future<void>? _connectFuture;

  Future<void> ensureConnected() async {
    if (_currentState == SignalRConnectionState.connected) {
      return;
    }

    if (_connectFuture != null) {
      return _connectFuture!;
    }

    _connectFuture = _doConnect().whenComplete(() {
      _connectFuture = null;
    });

    return _connectFuture!;
  }

  Future<void> _doConnect() async {
    if (_hubConnection.state == HubConnectionState.Connected) {
      _updateState(SignalRConnectionState.connected);
      return;
    }

    if (_hubConnection.state == HubConnectionState.Connecting ||
        _hubConnection.state == HubConnectionState.Reconnecting) {
      _updateState(SignalRConnectionState.connecting);
      return;
    }

    if (_hubConnection.state == HubConnectionState.Disconnected) {
      _updateState(SignalRConnectionState.connecting);
      try {
        await _hubConnection.start();
        _updateState(SignalRConnectionState.connected);
        _logger.i('SignalR connected');
      } catch (e) {
        _updateState(SignalRConnectionState.disconnected);
        _logger.e('SignalR connect failed: $e');
        rethrow;
      }
    }
  }

  Future<void> connect() async {
    await ensureConnected();
  }

  Future<void> safeStart() async {
    if (_hubConnection.state != HubConnectionState.Disconnected) return;
    await _hubConnection.start();
  }

  Future<void> disconnect() async {
    await _hubConnection.stop();
    _updateState(SignalRConnectionState.disconnected);
    _logger.i('SignalR disconnected');
  }

  Future<Object?> invoke(String method, {List<Object>? args}) async {
    _logger.d('SignalR invoke: $method');
    return _hubConnection.invoke(method, args: args);
  }

  void on(String event, void Function(List<Object?>?) handler) {
    _hubConnection.on(event, handler);
  }

  void off(String event) {
    _hubConnection.off(event);
  }

  void _updateState(SignalRConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  Future<void> dispose() async {
    await _hubConnection.stop();
    await _connectionStateController.close();
  }
}
