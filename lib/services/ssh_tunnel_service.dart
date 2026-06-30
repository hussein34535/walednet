import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

const bool kDebugMode = !bool.fromEnvironment('dart.vm.product');

class SshTunnelService {
  static final SshTunnelService _instance = SshTunnelService._internal();
  factory SshTunnelService() => _instance;
  SshTunnelService._internal();

  SSHClient? _sshClient;
  SSHDynamicForward? _sshForward;
  bool _isClosed = true;

  bool get isActive => _sshClient != null && !_isClosed;

  Future<void> startTunnel({
    required String host,
    required int port,
    required String username,
    required String password,
    String? sni,
    bool useSsl = false,
    bool useWs = false,
    String wsPath = '/',
    int localPort = 10808,
  }) async {
    await stopTunnel(); // Make sure previous tunnel is closed
    _isClosed = false;

    try {
      Socket baseSocket;

      if (useSsl) {
        // SSH over SSL/TLS
        final Socket rawSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
        baseSocket = await SecureSocket.secure(
          rawSocket,
          host: (sni != null && sni.isNotEmpty) ? sni : host,
          onBadCertificate: (cert) => true,
        );
      } else if (useWs) {
        // SSH over WebSocket Upgrade (HTTP Tunnel)
        baseSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
        
        final String sniHeader = (sni != null && sni.isNotEmpty) ? sni : host;
        final String handshake = 
            "GET $wsPath HTTP/1.1\r\n"
            "Host: $sniHeader\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "User-Agent: WaledNetVPN/1.4\r\n\r\n";
        
        baseSocket.write(handshake);
        await baseSocket.flush();

        // Read and discard HTTP response headers
        final List<int> buffer = [];
        final Completer<void> handshakeCompleter = Completer<void>();
        
        StreamSubscription<Uint8List>? subscription;
        subscription = baseSocket.listen(
          (data) {
            buffer.addAll(data);
            final responseStr = String.fromCharCodes(buffer);
            if (responseStr.contains("\r\n\r\n")) {
              subscription?.pause();
              if (responseStr.startsWith("HTTP/1.1 101") || responseStr.startsWith("HTTP/1.0 101")) {
                handshakeCompleter.complete();
              } else {
                handshakeCompleter.completeError(Exception("WebSocket upgrade failed: $responseStr"));
              }
            }
          },
          onError: (e) => handshakeCompleter.completeError(e),
          onDone: () => handshakeCompleter.completeError(Exception("Socket closed during WebSocket handshake")),
          cancelOnError: true,
        );

        try {
          await handshakeCompleter.future;
          subscription.cancel();
        } catch (e) {
          subscription.cancel();
          baseSocket.destroy();
          rethrow;
        }
      } else {
        // Direct SSH Connection
        baseSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      }

      // Initialize SSH Client with SSHSocket wrapper
      _sshClient = SSHClient(
        RawSSHSocket(baseSocket),
        username: username,
        onPasswordRequest: () => password,
      );

      // Authenticate
      await _sshClient!.authenticated.timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        print("[SshTunnelService] SSH Authenticated successfully.");
      }

      // Start SOCKS5 Dynamic Forwarding (ssh -D equivalent)
      _sshForward = await _sshClient!.forwardDynamic(
        bindHost: '127.0.0.1',
        bindPort: localPort,
      );
      
      if (kDebugMode) {
        print("[SshTunnelService] SSH Dynamic Forwarding (SOCKS5) started on local port $localPort.");
      }

    } catch (e) {
      if (kDebugMode) {
        print("[SshTunnelService] Connection failed: $e");
      }
      await stopTunnel();
      rethrow;
    }
  }

  Future<void> stopTunnel() async {
    _isClosed = true;
    
    try {
      await _sshForward?.close();
    } catch (_) {}
    _sshForward = null;

    try {
      _sshClient?.close();
    } catch (_) {}
    _sshClient = null;
    
    if (kDebugMode) {
      print("[SshTunnelService] SSH Tunnel stopped.");
    }
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
