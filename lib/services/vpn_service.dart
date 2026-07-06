import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

enum VpnState {
  disconnected,
  connecting,
  connected,
  error,
}

class VpnStatus {
  final VpnState state;
  final String message;
  final int uplink;
  final int downlink;

  VpnStatus({
    required this.state,
    this.message = '',
    this.uplink = 0,
    this.downlink = 0,
  });
}

class VpnService {
  static const _methodChannel = MethodChannel('waled_net/vpn');
  static const _statusEventChannel = EventChannel('waled_net/status');
  static const _trafficEventChannel = EventChannel('waled_net/traffic');
  static const _logEventChannel = EventChannel('waled_net/logs');

  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  final _statusController = StreamController<VpnStatus>.broadcast();
  Stream<VpnStatus> get statusStream => _statusController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  VpnState _state = VpnState.disconnected;
  VpnState get state => _state;

  StreamSubscription? _statusSub;
  StreamSubscription? _trafficSub;
  StreamSubscription? _logSub;

  void initialize() {
    _statusSub = _statusEventChannel.receiveBroadcastStream().listen((data) {
      final message = data.toString();
      _updateState(message);
    });

    _trafficSub = _trafficEventChannel.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        final uplink = (data['uplink'] ?? 0) as num;
        final downlink = (data['downlink'] ?? 0) as num;
        _statusController.add(VpnStatus(
          state: _state,
          uplink: uplink.toInt(),
          downlink: downlink.toInt(),
        ));
      }
    });

    _logSub = _logEventChannel.receiveBroadcastStream().listen((data) {
      _logController.add(data.toString());
    }, onError: (err) {
      _logController.add('Log Error: $err');
    });
  }

  void _updateState(String message) {
    if (message.contains('start') || message.contains('connecting')) {
      _state = VpnState.connecting;
    } else if (message.contains('started') || message.contains('connected')) {
      _state = VpnState.connected;
    } else if (message.contains('stop') || message.contains('closed')) {
      _state = VpnState.disconnected;
    } else if (message.contains('error') || message.contains('failed')) {
      _state = VpnState.error;
    }
    _statusController.add(VpnStatus(state: _state, message: message));
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methodChannel.invokeMethod('prepare') ?? false;
    } catch (e) {
      print('[VpnService] prepare error: $e');
      return false;
    }
  }

  Future<bool> start({required String configJson}) async {
    if (!Platform.isAndroid) return false;
    try {
      _state = VpnState.connecting;
      _statusController.add(VpnStatus(state: _state, message: 'connecting'));
      final result = await _methodChannel.invokeMethod('start', {
        'config': configJson,
      });
      return result ?? false;
    } catch (e) {
      _state = VpnState.error;
      _statusController.add(VpnStatus(state: _state, message: e.toString()));
      print('[VpnService] start error: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod('stop');
      _state = VpnState.disconnected;
      _statusController.add(VpnStatus(state: _state, message: 'disconnected'));
    } catch (e) {
      print('[VpnService] stop error: $e');
    }
  }

  Future<bool> isConnected() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod('isConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _statusSub?.cancel();
    _trafficSub?.cancel();
    _logSub?.cancel();
    _statusController.close();
    _logController.close();
  }
}
