import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

class SshTunnelService {
  static final SshTunnelService _instance = SshTunnelService._internal();
  factory SshTunnelService() => _instance;
  SshTunnelService._internal();

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _isolateSendPort;

  bool _isClosed = true;
  bool _hasEverConnected = false;
  int _localPort = 10809;

  // Keepalive & reconnect
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 6;

  // Stored params for reconnect
  String? _host;
  int? _port;
  String? _username;
  String? _password;
  String? _sni;
  bool _useSsl = false;

  // Callbacks — يربطها VpnProvider
  void Function(bool connected)? onConnectionChanged;
  void Function(String message)? onStatusUpdate;

  bool get isActive => _isolate != null && !_isClosed;
  int get localSocksPort => _localPort;

  // ──────────────────────────────────────────────
  // PUBLIC API
  // ──────────────────────────────────────────────

  Future<void> startTunnel({
    required String host,
    required int port,
    required String username,
    required String password,
    String? sni,
    bool useSsl = false,
    int localPort = 10809,
  }) async {
    _isClosed = false;
    _reconnectAttempts = 0;
    _hasEverConnected = false;

    // حفظ الـ params عشان نستخدمهم في الـ reconnect
    _host = host;
    _port = port;
    _username = username;
    _password = password;
    _sni = sni;
    _useSsl = useSsl;
    _localPort = localPort;

    await _connect();
  }

  Future<void> stopTunnel() async {
    _isClosed = true;
    _hasEverConnected = false;
    _reconnectAttempts = _maxReconnectAttempts; // منع أي reconnect
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_isolateSendPort != null) {
      try {
        _isolateSendPort!.send({'action': 'stop'});
      } catch (_) {}
      _isolateSendPort = null;
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
    try { _isolate?.kill(priority: Isolate.immediate); } catch (_) {}
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;

    _host = null;
    _log('Stopped by user');
  }

  // ──────────────────────────────────────────────
  // INTERNAL CONNECTION LOGIC
  // ──────────────────────────────────────────────

  Future<void> _connect() async {
    if (_host == null || _isClosed) return;

    // تنظيف أي آيسوليت شغال سابقاً
    if (_isolateSendPort != null) {
      try {
        _isolateSendPort!.send({'action': 'stop'});
      } catch (_) {}
      _isolateSendPort = null;
    }
    _receivePort?.close();
    _receivePort = null;
    _isolate = null;

    _receivePort = ReceivePort();
    Completer<void> connectCompleter = Completer<void>();

    _receivePort!.listen((message) async {
      if (message is SendPort) {
        _isolateSendPort = message;
        // أرسل بارامترات الاتصال للبدء في الخلفية
        _isolateSendPort!.send({
          'action': 'connect',
          'host': _host,
          'port': _port,
          'username': _username,
          'password': _password,
          'sni': _sni,
          'useSsl': _useSsl,
          'localPort': _localPort,
        });
      } else if (message is Map<String, dynamic>) {
        final type = message['type'];
        if (type == 'log') {
          _log(message['message']);
        } else if (type == 'ready') {
          _localPort = message['port'] as int;
          _log('SOCKS5 proxy ready on 127.0.0.1:$_localPort ✓');
          _reconnectAttempts = 0;
          _hasEverConnected = true;
          onConnectionChanged?.call(true);
          if (!connectCompleter.isCompleted) {
            connectCompleter.complete();
          }
        } else if (type == 'error') {
          final errMsg = message['message'];
          _log('Connection failed: $errMsg');
          
          if (_hasEverConnected) {
            onConnectionChanged?.call(false);
            _scheduleReconnect();
          } else {
            if (!connectCompleter.isCompleted) {
              connectCompleter.completeError(Exception(errMsg));
            }
          }
        } else if (type == 'disconnected') {
          final msg = message['message'];
          _log('Disconnected: $msg');
          if (!_isClosed) {
            _handleUnexpectedDisconnect();
          }
        }
      }
    });

    try {
      _isolate = await Isolate.spawn(_sshTunnelIsolateEntry, _receivePort!.sendPort);
      await connectCompleter.future.timeout(const Duration(seconds: 35));
    } catch (e) {
      if (!_hasEverConnected) {
        rethrow;
      }
    }
  }

  void _handleUnexpectedDisconnect() {
    if (_isClosed) return;
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isClosed || _host == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('Max reconnect attempts ($_maxReconnectAttempts) reached. Giving up.');
      onStatusUpdate?.call('reconnect_failed');
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = _reconnectAttempts <= 4
        ? (2 * _reconnectAttempts)
        : 30;
    final delay = Duration(seconds: delaySeconds);

    _log('Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s...');
    onStatusUpdate?.call('reconnecting:$_reconnectAttempts');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!_isClosed && _host != null) {
        await _connect();
      }
    });
  }

  void _log(String msg) {
    print('[SshTunnel] $msg');
    onStatusUpdate?.call(msg);
  }
}

// دالة العمل الخاصة بالـ Isolate للاتصال في خلفية النظام
@pragma('vm:entry-point')
void _sshTunnelIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  SSHClient? sshClient;
  SSHDynamicForward? forward;
  Socket? activeSocket;
  Timer? keepaliveTimer;
  bool isClosed = false;

  receivePort.listen((message) async {
    if (message is Map<String, dynamic>) {
      final action = message['action'];
      if (action == 'connect') {
        final host = message['host'] as String;
        final port = message['port'] as int;
        final username = message['username'] as String;
        final password = message['password'] as String;
        final sni = message['sni'] as String?;
        final useSsl = message['useSsl'] as bool;
        final localPort = message['localPort'] as int;

        Future<void> cleanUp() async {
          keepaliveTimer?.cancel();
          keepaliveTimer = null;
          try { activeSocket?.destroy(); } catch (_) {}
          activeSocket = null;
          try { await forward?.close(); } catch (_) {}
          forward = null;
          try { sshClient?.close(); } catch (_) {}
          sshClient = null;
        }

        try {
          final candidates = [
            {'port': port, 'useSsl': useSsl},
          ];

        Object? lastError;
        for (int i = 0; i < candidates.length; i++) {
          final cand = candidates[i];
          final curPort = cand['port'] as int;
          final curUseSsl = cand['useSsl'] as bool;

          try {
            mainSendPort.send({
              'type': 'log',
              'message': 'Connecting to $host:$curPort (SSL=$curUseSsl, SNI=$sni)'
            });

            Socket baseSocket = await Socket.connect(
              host,
              curPort,
              timeout: const Duration(seconds: 6),
            );
            baseSocket.setOption(SocketOption.tcpNoDelay, true);
            if (isClosed) {
              baseSocket.destroy();
              return;
            }
            activeSocket = baseSocket;
            mainSendPort.send({'type': 'log', 'message': 'TCP connected on port $curPort'});

            if (curUseSsl) {
              final sniHost = (sni != null && sni.isNotEmpty) ? sni : host;
              mainSendPort.send({'type': 'log', 'message': 'Securing with TLS. SNI: $sniHost'});
              final secureSocket = await SecureSocket.secure(
                baseSocket,
                host: sniHost,
                onBadCertificate: (_) {
                  mainSendPort.send({'type': 'log', 'message': 'Bad TLS cert accepted'});
                  return true;
                },
              ).timeout(const Duration(seconds: 8));

              if (isClosed) {
                secureSocket.destroy();
                return;
              }
              activeSocket = secureSocket;
              mainSendPort.send({'type': 'log', 'message': 'TLS secured'});
            }

            mainSendPort.send({'type': 'log', 'message': 'Initializing SSH client...'});
            sshClient = SSHClient(
              RawSSHSocket(activeSocket!),
              username: username,
              onPasswordRequest: () => password,
              keepAliveInterval: const Duration(seconds: 20),
            );

            mainSendPort.send({'type': 'log', 'message': 'Authenticating...'});
            await sshClient!.authenticated.timeout(const Duration(seconds: 25));

            if (isClosed) {
              await cleanUp();
              return;
            }
            mainSendPort.send({'type': 'log', 'message': 'SSH authenticated √'});
            lastError = null;
            break;
          } catch (e) {
            lastError = e;
            await cleanUp();
            if (i < candidates.length - 1) {
              final nextCand = candidates[i + 1];
              mainSendPort.send({
                'type': 'log',
                'message': 'Port $curPort failed ($e). Auto-falling back to port ${nextCand['port']}...'
              });
            }
          }
        }

        if (lastError != null || sshClient == null) {
          throw lastError ?? Exception('SSH connection failed on all ports');
        }

          mainSendPort.send({'type': 'log', 'message': 'Starting SOCKS5 proxy on 127.0.0.1:$localPort...'});
          forward = await sshClient!.forwardDynamic(
            bindHost: '127.0.0.1',
            bindPort: localPort,
          ).timeout(const Duration(seconds: 10));

          if (isClosed) {
            await cleanUp();
            return;
          }
          
          mainSendPort.send({
            'type': 'ready',
            'port': forward!.port,
          });

          // مراقبة إغلاق الـ SSH
          sshClient!.done.then((_) {
            if (!isClosed) {
              mainSendPort.send({'type': 'disconnected', 'message': 'Connection dropped unexpectedly!'});
            }
          }).catchError((e) {
            if (!isClosed) {
              mainSendPort.send({'type': 'disconnected', 'message': 'Connection error: $e'});
            }
          });

          // مؤقت الـ Heartbeat/Keepalive داخل الـ Isolate
          keepaliveTimer?.cancel();
          keepaliveTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
            if (sshClient == null || isClosed) return;
            try {
              await sshClient!.ping().timeout(const Duration(seconds: 8));
              mainSendPort.send({'type': 'log', 'message': 'Keepalive ✓'});
            } catch (e) {
              mainSendPort.send({'type': 'disconnected', 'message': 'Keepalive failed: $e'});
            }
          });

        } catch (e) {
          mainSendPort.send({'type': 'error', 'message': e.toString()});
          await cleanUp();
        }
      } else if (action == 'stop') {
        isClosed = true;
        keepaliveTimer?.cancel();
        keepaliveTimer = null;
        try { activeSocket?.destroy(); } catch (_) {}
        activeSocket = null;
        try { await forward?.close(); } catch (_) {}
        forward = null;
        try { sshClient?.close(); } catch (_) {}
        sshClient = null;
        receivePort.close();
        Isolate.current.kill();
      }
    }
  });
}

// ──────────────────────────────────────────────
// Raw socket wrapper for dartssh2
// ──────────────────────────────────────────────

class RawSSHSocket implements SSHSocket {
  final Socket _socket;
  RawSSHSocket(this._socket);

  @override
  Stream<Uint8List> get stream => _socket;
  @override
  StreamSink<List<int>> get sink => _socket;
  @override
  Future<void> close() => _socket.close();
  @override
  Future<void> get done => _socket.done;
  @override
  void destroy() => _socket.destroy();
  @override
  Future<void> flush() => _socket.flush();
}
