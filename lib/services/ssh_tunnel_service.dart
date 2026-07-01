import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

const bool kDebugMode = !bool.fromEnvironment('dart.vm.product');

class SshTunnelService {
  static final SshTunnelService _instance = SshTunnelService._internal();
  factory SshTunnelService() => _instance;
  SshTunnelService._internal();

  SSHClient? _sshClient;
  ServerSocket? _socksServer;
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
    await stopTunnel();
    _isClosed = false;

    if (Platform.isWindows) {
      try {
        await Process.run('powershell', [
          '-Command',
          '\$conn = Get-NetTCPConnection -LocalPort $localPort -ErrorAction SilentlyContinue; if (\$conn) { Stop-Process -Id \$conn.OwningProcess -Force -ErrorAction SilentlyContinue }'
        ]);
      } catch (e) {
        print('[SshTunnelService] Error clearing port $localPort: $e');
      }
    }

    try {
      print('[SshTunnelService] Connecting to base socket: $host:$port');
      Socket baseSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      print('[SshTunnelService] Base socket connected.');

      if (useSsl) {
        final sniHeader = (sni != null && sni.isNotEmpty) ? sni : host;
        print('[SshTunnelService] Securing socket with SSL/TLS. Host SNI: $sniHeader');
        baseSocket = await SecureSocket.secure(
          baseSocket,
          host: sniHeader,
          onBadCertificate: (cert) => true,
        ).timeout(const Duration(seconds: 10));
        print('[SshTunnelService] Socket secured successfully.');
      }

      if (useWs) {
        final String sniHeader = (sni != null && sni.isNotEmpty) ? sni : host;
        print('[SshTunnelService] Initiating WebSocket handshake for path: $wsPath');
        final String handshake =
            "GET $wsPath HTTP/1.1\r\n"
            "Host: $sniHeader\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "User-Agent: WaledNetVPN/1.4\r\n\r\n";

        baseSocket.write(utf8.encode(handshake));
        await baseSocket.flush();

        final List<int> buffer = [];
        final Completer<void> handshakeCompleter = Completer<void>();

        StreamSubscription<List<int>>? subscription;
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
          await handshakeCompleter.future.timeout(const Duration(seconds: 10));
          print('[SshTunnelService] WebSocket handshake successful.');
          subscription.cancel();
        } catch (e) {
          subscription.cancel();
          baseSocket.destroy();
          print('[SshTunnelService] WebSocket handshake failed: $e');
          rethrow;
        }
      }

      print('[SshTunnelService] Initializing SSH Client...');
      _sshClient = SSHClient(
        RawSSHSocket(baseSocket),
        username: username,
        onPasswordRequest: () => password,
      );

      print('[SshTunnelService] Authenticating SSH...');
      await _sshClient!.authenticated.timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        print("[SshTunnelService] SSH Authenticated successfully.");
      }

      print('[SshTunnelService] Binding local SOCKS5 server on port $localPort...');
      _socksServer = await ServerSocket.bind('127.0.0.1', localPort);
      _socksServer!.listen(_handleSocksClient);

      if (kDebugMode) {
        print("[SshTunnelService] Custom SOCKS5 proxy started on port $localPort.");
      }

      if (kDebugMode) {
        _testSocksProxy(localPort);
      }

    } catch (e) {
      if (kDebugMode) {
        print("[SshTunnelService] Connection failed: $e");
      }
      await stopTunnel();
      rethrow;
    }
  }

  void _handleSocksClient(Socket client) {
    if (_isClosed) {
      client.destroy();
      return;
    }

    final buffer = <int>[];
    SSHForwardChannel? remote;
    StreamSubscription<Uint8List>? remoteSub;
    StreamSubscription<List<int>>? clientSub;
    var state = 0; // 0=greeting, 1=request, 2=streaming

    clientSub = client.listen(
      (data) {
        buffer.addAll(data);
        if (state == 0) {
          if (buffer.length < 2) return;
          final ver = buffer[0];
          final nmethods = buffer[1];
          if (buffer.length < 2 + nmethods) return;
          if (ver != 0x05) {
            client.add([0x05, 0xFF]);
            client.destroy();
            return;
          }
          if (!buffer.sublist(2, 2 + nmethods).contains(0x00)) {
            client.add([0x05, 0xFF]);
            client.destroy();
            return;
          }
          buffer.removeRange(0, 2 + nmethods);
          client.add([0x05, 0x00]);
          state = 1;
        }
        if (state == 1) {
          if (buffer.length < 4) return;
          final ver = buffer[0];
          final cmd = buffer[1];
          final atyp = buffer[3];
          if (ver != 0x05 || cmd != 0x01) {
            _sendSocksReply(client, 0x07);
            client.destroy();
            return;
          }
          int headerLen;
          String host;
          if (atyp == 0x01) {
            headerLen = 10;
            if (buffer.length < headerLen) return;
            host = '${buffer[4]}.${buffer[5]}.${buffer[6]}.${buffer[7]}';
          } else if (atyp == 0x03) {
            if (buffer.length < 5) return;
            final len = buffer[4];
            headerLen = 7 + len;
            if (buffer.length < headerLen) return;
            host = utf8.decode(buffer.sublist(5, 5 + len));
          } else if (atyp == 0x04) {
            headerLen = 22;
            if (buffer.length < headerLen) return;
            host = '';
            for (int i = 4; i < 20; i++) {
              host += buffer[i].toRadixString(16).padLeft(2, '0');
              if (i < 19) host += ':';
            }
          } else {
            _sendSocksReply(client, 0x08);
            client.destroy();
            return;
          }
          final port = (buffer[headerLen - 2] << 8) | buffer[headerLen - 1];
          buffer.removeRange(0, headerLen);

          if (_sshClient == null) {
            _sendSocksReply(client, 0x05);
            client.destroy();
            return;
          }

          _sshClient!.forwardLocal(host, port).then((ch) {
            remote = ch;
            _sendSocksReply(client, 0x00);
            state = 2;

            remoteSub = ch.stream.listen(
              (remoteData) {
                client.add(remoteData);
              },
              onDone: () => client.destroy(),
              onError: (_, __) => client.destroy(),
            );

            if (buffer.isNotEmpty) {
              ch.sink.add(buffer.toList());
              buffer.clear();
            }
          }).catchError((_) {
            _sendSocksReply(client, 0x04);
            client.destroy();
          });
        }
        if (state == 2) {
          remote?.sink.add(buffer.toList());
          buffer.clear();
        }
      },
      onDone: () {
        remoteSub?.cancel();
        remote?.destroy();
      },
      onError: (_, __) {
        remoteSub?.cancel();
        remote?.destroy();
      },
    );
  }

  void _sendSocksReply(Socket client, int code) {
    client.add(Uint8List.fromList([
      0x05, code, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00,
    ]));
  }

  Future<void> _testSocksProxy(int localPort) async {
    try {
      final socket = await Socket.connect('127.0.0.1', localPort,
          timeout: const Duration(seconds: 5));
      final completer = Completer<void>();
      var handshakeDone = false;

      socket.listen(
        (data) {
          if (!handshakeDone && data.length >= 2 && data[0] == 0x05 && data[1] == 0x00) {
            handshakeDone = true;
            socket.add(Uint8List.fromList([
              0x05, 0x01, 0x00, 0x01,
              0x01, 0x01, 0x01, 0x01,
              0x00, 0x50,
            ]));
            socket.flush();
          } else if (handshakeDone && data.length >= 2 && data[0] == 0x05) {
            if (data[1] == 0x00) {
              print('[SshTunnelService] SOCKS5 proxy test: SUCCESS');
            } else {
              print('[SshTunnelService] SOCKS5 proxy test: FAILED code ${data[1]}');
            }
            socket.destroy();
            completer.complete();
          }
        },
        onError: (e) {
          print('[SshTunnelService] SOCKS5 proxy test error: $e');
          completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) {
            print('[SshTunnelService] SOCKS5 proxy test: connection closed');
            completer.complete();
          }
        },
      );

      socket.add([0x05, 0x01, 0x00]);
      await socket.flush();

      await completer.future.timeout(const Duration(seconds: 10),
          onTimeout: () => print('[SshTunnelService] SOCKS5 proxy test: timeout'));
    } catch (e) {
      print('[SshTunnelService] SOCKS5 proxy test error: $e');
    }
  }

  Future<void> stopTunnel() async {
    _isClosed = true;

    try {
      await _socksServer?.close();
    } catch (_) {}
    _socksServer = null;

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
