import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

class SshTunnelService {
  static final SshTunnelService _instance = SshTunnelService._internal();
  factory SshTunnelService() => _instance;
  SshTunnelService._internal();

  SSHClient? _sshClient;
  SSHDynamicForward? _forward;
  bool _isClosed = true;
  int _localPort = 10809;

  bool get isActive => _sshClient != null && !_isClosed;
  int get localSocksPort => _localPort;

  Future<void> startTunnel({
    required String host,
    required int port,
    required String username,
    required String password,
    String? sni,
    bool useSsl = false,
    int localPort = 10809,
  }) async {
    await stopTunnel();
    _isClosed = false;
    _localPort = localPort;

    try {
      print('[SshTunnel] Connecting to $host:$port (SSL=$useSsl, SNI=$sni)');

      Socket baseSocket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
      print('[SshTunnel] TCP connected');

      if (useSsl) {
        final sniHost = (sni != null && sni.isNotEmpty) ? sni : host;
        print('[SshTunnel] Securing with TLS. SNI: $sniHost');
        baseSocket = await SecureSocket.secure(
          baseSocket,
          host: sniHost,
          onBadCertificate: (cert) {
            print('[SshTunnel] Bad TLS cert accepted (SSH-over-TLS)');
            return true;
          },
        ).timeout(const Duration(seconds: 10));
        print('[SshTunnel] TLS secured (SNI=$sniHost)');
      }

      print('[SshTunnel] Initializing SSH client...');
      _sshClient = SSHClient(
        RawSSHSocket(baseSocket),
        username: username,
        onPasswordRequest: () => password,
      );

      print('[SshTunnel] Authenticating...');
      await _sshClient!.authenticated.timeout(const Duration(seconds: 15));
      print('[SshTunnel] SSH authenticated');

      print('[SshTunnel] Starting SOCKS5 proxy on 127.0.0.1:$localPort...');
      _forward = await _sshClient!.forwardDynamic(
        bindHost: '127.0.0.1',
        bindPort: localPort,
      ).timeout(const Duration(seconds: 10));

      _localPort = _forward!.port;
      print('[SshTunnel] SOCKS5 proxy ready on 127.0.0.1:$_localPort');

    } catch (e) {
      print('[SshTunnel] Failed: $e');
      await stopTunnel();
      rethrow;
    }
  }

  Future<void> stopTunnel() async {
    _isClosed = true;
    try { _forward?.close(); } catch (_) {}
    _forward = null;
    try { _sshClient?.close(); } catch (_) {}
    _sshClient = null;
    print('[SshTunnel] Stopped');
  }
}

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
