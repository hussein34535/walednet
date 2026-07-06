import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

class SshTunnelService {
  static final SshTunnelService _instance = SshTunnelService._internal();
  factory SshTunnelService() => _instance;
  SshTunnelService._internal();

  SSHClient? _sshClient;
  SSHDynamicForward? _forward;
  Socket? _activeSocket;
  bool _isClosed = true;
  bool _hasEverConnected = false;
  int _localPort = 10809;

  // Keepalive & reconnect
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 6;
  static const Duration _keepaliveInterval = Duration(seconds: 25);

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

  bool get isActive => _sshClient != null && !_isClosed;
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
    await _cleanUp();
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
    await _cleanUp();
    _host = null;
    print('[SshTunnel] Stopped by user');
  }

  // ──────────────────────────────────────────────
  // INTERNAL CONNECTION LOGIC
  // ──────────────────────────────────────────────

  Future<void> _connect() async {
    if (_host == null || _isClosed) return;

    try {
      _log('Connecting to $_host:$_port (SSL=$_useSsl, SNI=$_sni)');

      Socket baseSocket = await Socket.connect(
        _host!,
        _port!,
        timeout: const Duration(seconds: 10),
      );
      if (_isClosed) {
        baseSocket.destroy();
        return;
      }
      _activeSocket = baseSocket;
      _log('TCP connected');

      if (_useSsl) {
        final sniHost = (_sni != null && _sni!.isNotEmpty) ? _sni! : _host!;
        _log('Securing with TLS. SNI: $sniHost');
        final secureSocket = await SecureSocket.secure(
          baseSocket,
          host: sniHost,
          onBadCertificate: (_) {
            _log('Bad TLS cert accepted (SSH-over-TLS)');
            return true;
          },
        ).timeout(const Duration(seconds: 10));
        
        if (_isClosed) {
          secureSocket.destroy();
          return;
        }
        _activeSocket = secureSocket;
        _log('TLS secured');
      }

      _log('Initializing SSH client...');
      _sshClient = SSHClient(
        RawSSHSocket(_activeSocket!),
        username: _username!,
        onPasswordRequest: () => _password!,
        keepAliveInterval: const Duration(seconds: 20),
      );

      _log('Authenticating...');
      await _sshClient!.authenticated.timeout(const Duration(seconds: 30));
      
      if (_isClosed) {
        await _cleanUp();
        return;
      }
      _log('SSH authenticated √');

      _log('Starting SOCKS5 proxy on 127.0.0.1:$_localPort...');
      _forward = await _sshClient!.forwardDynamic(
        bindHost: '127.0.0.1',
        bindPort: _localPort,
      ).timeout(const Duration(seconds: 10));

      if (_isClosed) {
        await _cleanUp();
        return;
      }
      _localPort = _forward!.port;
      _log('SOCKS5 proxy ready on 127.0.0.1:$_localPort ✓');

      // ابدأ keepalive + monitor
      _startKeepalive();
      _monitorConnection();

      _reconnectAttempts = 0;
      _hasEverConnected = true;
      onConnectionChanged?.call(true);

    } catch (e) {
      if (_isClosed) {
        _log('Connection aborted by user during connect/auth phase.');
        return;
      }
      _log('Connection failed: $e');
      await _cleanUp(clearParams: false);

      if (_hasEverConnected) {
        // الـ tunnel كان شغال فعلاً وانقطع — بلّغ الـ VpnProvider
        onConnectionChanged?.call(false);
        _scheduleReconnect();
      } else {
        // أول محاولة اتصال فشلت — ارمي الخطأ للـ caller (VpnProvider._connectToVpn)
        // بدون ما نشغل reconnect أو نبلغ بتغيير حالة الاتصال
        rethrow;
      }
    }
  }

  // ──────────────────────────────────────────────
  // KEEPALIVE — ping كل 25 ثانية
  // ──────────────────────────────────────────────

  void _startKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (_) async {
      if (_sshClient == null || _isClosed) return;
      try {
        // نبعت channel request صغير كـ heartbeat
        await _sshClient!.ping().timeout(const Duration(seconds: 8));
        _log('Keepalive ✓');
      } catch (e) {
        _log('Keepalive failed: $e — triggering reconnect');
        _handleUnexpectedDisconnect();
      }
    });
  }

  // ──────────────────────────────────────────────
  // MONITOR — راقب لو الـ SSH connection انكسر
  // ──────────────────────────────────────────────

  void _monitorConnection() {
    _sshClient?.done.then((_) {
      if (!_isClosed) {
        _log('Connection dropped unexpectedly!');
        _handleUnexpectedDisconnect();
      }
    }).catchError((e) {
      if (!_isClosed) {
        _log('Connection error: $e');
        _handleUnexpectedDisconnect();
      }
    });
  }

  void _handleUnexpectedDisconnect() {
    if (_isClosed) return;
    _keepaliveTimer?.cancel();
    _forward = null;
    _sshClient = null;
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }

  // ──────────────────────────────────────────────
  // AUTO-RECONNECT — exponential backoff
  // ──────────────────────────────────────────────

  void _scheduleReconnect() {
    if (_isClosed || _host == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('Max reconnect attempts ($_maxReconnectAttempts) reached. Giving up.');
      onStatusUpdate?.call('reconnect_failed');
      return;
    }

    _reconnectAttempts++;
    // Exponential backoff: 2s, 4s, 8s, 16s, 30s, 30s
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

  // ──────────────────────────────────────────────
  // CLEANUP
  // ──────────────────────────────────────────────

  Future<void> _cleanUp({bool clearParams = true}) async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      _activeSocket?.destroy();
    } catch (_) {}
    _activeSocket = null;

    try { _forward?.close(); } catch (_) {}
    _forward = null;

    try { _sshClient?.close(); } catch (_) {}
    _sshClient = null;

    if (clearParams) {
      _reconnectAttempts = 0;
    }
  }

  void _log(String msg) {
    print('[SshTunnel] $msg');
    onStatusUpdate?.call(msg);
  }
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
}
