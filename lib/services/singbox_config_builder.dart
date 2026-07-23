import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' show sha256;

class SingboxConfigBuilder {
  static String build({
    required String serverUrl,
    String? sni,
    String? sniProfileName,
    int sshLocalPort = 10809,
    String? resolvedIp,
  }) {
    final isSsh = serverUrl.startsWith('ssh://');
    final isSlowDns = serverUrl.startsWith('slowdns://');
    final outbound = _buildOutbound(serverUrl, sni, sshLocalPort, resolvedIp: resolvedIp);
    final serverHost = outbound['server'] as String?;

    // Extract resolver IP for SlowDNS to avoid routing loop (TUN → proxy → resolver → TUN)
    String? slowDnsResolverIp;
    if (isSlowDns) {
      final uri = Uri.parse(serverUrl);
      slowDnsResolverIp = uri.queryParameters['dns_ip'];
    }

    final config = {
      'log': {
        'level': 'warn',
        'timestamp': true,
      },
      'dns': {
        'servers': [
          {
            'tag': 'dns-proxy',
            'type': 'tcp',
            'server': '1.1.1.1',
            'detour': 'proxy',
          },
          {
            'tag': 'dns-direct',
            'type': 'udp',
            'server': '223.5.5.5',
          },
        ],
        'rules': [
          if (serverHost != null && serverHost != '127.0.0.1')
            {
              'domain': [serverHost],
              'server': 'dns-direct',
            },
          {
            'outbound': ['direct'],
            'server': 'dns-direct',
          },
        ],
        'final': isSsh || isSlowDns ? 'dns-direct' : 'dns-proxy',
        'strategy': 'ipv4_only',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'address': '172.19.0.1/30',
          'mtu': 1500,
          'auto_route': true,
          'stack': 'gvisor',
          'platform': {
            'http_proxy': {
              'enabled': false,
            },
          },
        },
      ],
      'outbounds': [
        outbound,
        {
          'type': 'direct',
          'tag': 'direct',
        },
        {
          'type': 'block',
          'tag': 'block',
        },
      ],
      'route': {
        'auto_detect_interface': false,
        'rules': [
          {
            'port': [53],
            'action': 'hijack-dns',
          },
          {
            'action': 'sniff',
          },
          // For SlowDNS: resolver IP bypasses VPN to avoid TUN loop
          if (isSlowDns && slowDnsResolverIp != null && slowDnsResolverIp.isNotEmpty)
            {
              'ip_cidr': ['$slowDnsResolverIp/32'],
              'outbound': 'direct',
            },
          {
            'ip_is_private': true,
            'outbound': 'direct',
          },
          // Block QUIC (UDP 443) for SSH/SlowDNS to force fallback to TCP (HTTPS), while allowing VLESS/VMess/Trojan to proxy UDP natively
          if (isSsh || isSlowDns)
            {
              'port': [443],
              'network': ['udp'],
              'outbound': 'block',
            },
          // For SSH, route other UDP directly so non-TCP apps don't hang
          if (isSsh)
            {
              'network': ['udp'],
              'outbound': 'direct',
            },
        ],
        'final': 'proxy',
      },
      'experimental': {
        'cache_file': {
          'enabled': true,
          'path': 'cache.db',
        },
      },
    };

    return jsonEncode(config);
  }

  static Map<String, dynamic> _buildOutbound(String url, String? sni, int sshLocalPort, {String? resolvedIp}) {
    if (url.startsWith('vless://')) {
      return _buildVlessOutbound(url, sni, resolvedIp: resolvedIp);
    } else if (url.startsWith('vmess://')) {
      return _buildVmessOutbound(url, sni, resolvedIp: resolvedIp);
    } else if (url.startsWith('ssh://')) {
      return _buildSshSocksOutbound(sshLocalPort);
    } else if (url.startsWith('trojan://')) {
      return _buildTrojanOutbound(url, sni, resolvedIp: resolvedIp);
    } else if (url.startsWith('slowdns://')) {
      return _buildSlowDnsOutbound(url, resolvedIp: resolvedIp);
    }
    throw Exception('Unsupported protocol: $url');
  }

  static Map<String, dynamic> _buildSlowDnsOutbound(String url, {String? resolvedIp}) {
    final uri = Uri.parse(url);
    final publicKey = uri.userInfo;
    final domain = uri.host;
    
    // Read the DNS IP from URL (primary resolver = the dnstt server IP)
    var dnsIp = uri.queryParameters['dns_ip'] ?? '';
    if (dnsIp.isEmpty && resolvedIp != null && resolvedIp.isNotEmpty) {
      dnsIp = resolvedIp;
    }
    if (dnsIp.isEmpty) {
      dnsIp = '8.8.8.8'; // ultimate fallback
    }
    if (!dnsIp.contains(':')) {
      dnsIp = '$dnsIp:53';
    }

    final resolvers = [dnsIp];

    return {
      'type': 'dnstt',
      'tag': 'proxy',
      'pubkey': publicKey,
      'domain': domain,
      'resolvers': resolvers,
      'mtu': 130,
      'record-type': 'cname',
    };
  }

  static Map<String, dynamic> _buildSshSocksOutbound(int sshLocalPort) {
    return {
      'type': 'socks',
      'tag': 'proxy',
      'server': '127.0.0.1',
      'server_port': sshLocalPort,
      'version': '5',
    };
  }

  static Map<String, dynamic> _buildVlessOutbound(String url, String? sni, {String? resolvedIp}) {
    final uri = Uri.parse(url);
    final uuid = uri.userInfo;
    final server = resolvedIp ?? uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    final security = query['security'] ?? 'none';
    final type = query['type'] ?? 'tcp';
    
    // TLS SNI uses the whitelisted SNI if provided, otherwise the original SNI or host
    final tlsSni = (sni != null && sni.isNotEmpty) ? sni : (query['sni'] ?? query['host'] ?? uri.host);
    
    final rawHost = query['host'] ?? query['sni'] ?? uri.host;
    final httpHost = (sni != null && sni.isNotEmpty && (security != 'tls' || !uri.host.contains('waled.online')))
        ? sni
        : rawHost;
    final path = query['path'] ?? '/';
    final flow = query['flow'];

    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'packet_encoding': 'xudp',
      if (flow != null && flow.isNotEmpty) 'flow': flow,
    };

    if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': tlsSni,
        'utls': {
          'enabled': true,
          'fingerprint': 'chrome',
        },
        'insecure': true,
      };
    } else if (security == 'reality') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': tlsSni,
        'reality': {
          'enabled': true,
          'public_key': query['pbk'] ?? '',
          'short_id': query['sid'] ?? '',
        },
        'utls': {
          'enabled': true,
          'fingerprint': query['fp'] ?? 'chrome',
        },
      };
    }

    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': path,
        'headers': {'Host': httpHost},
      };
    } else if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': query['serviceName'] ?? '',
      };
    } else if (type == 'http') {
      outbound['transport'] = {
        'type': 'http',
        'host': [httpHost],
        'path': path,
      };
    }

    return outbound;
  }

  static Map<String, dynamic> _buildVmessOutbound(String url, String? sni, {String? resolvedIp}) {
    final base64Str = url.substring('vmess://'.length);
    String normalized = base64Str;
    final mod = base64Str.length % 4;
    if (mod > 0) normalized += '=' * (4 - mod);
    final json = jsonDecode(utf8.decode(base64.decode(normalized)));

    final server = resolvedIp ?? json['add'] as String;
    final port = int.parse(json['port'].toString());
    final uuid = json['id'] as String;
    final aid = int.parse((json['aid'] ?? 0).toString());
    final security = json['tls'] ?? '';
    final type = json['net'] ?? 'tcp';
    
    final originalHost = json['add'] as String;
    final String rawSni = (json['sni']?.toString() ?? json['host']?.toString() ?? '').trim();
    final tlsSni = (sni != null && sni.isNotEmpty) ? sni : (rawSni.isNotEmpty ? rawSni : originalHost);
    
    final String rawHost = (json['host']?.toString() ?? json['sni']?.toString() ?? '').trim();
    final httpHost = (sni != null && sni.isNotEmpty && (security != 'tls' || !originalHost.contains('waled.online')))
        ? sni
        : (rawHost.isNotEmpty ? rawHost : originalHost);
    final path = json['path'] ?? '/';

    final outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': 'proxy',
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'alter_id': aid,
      'security': 'auto',
    };

    if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': tlsSni,
        'utls': {
          'enabled': true,
          'fingerprint': 'chrome',
        },
        'insecure': true,
      };
    }

    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': path,
        'headers': {'Host': httpHost},
      };
    } else if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': json['path'] ?? '',
      };
    }

    return outbound;
  }

  static Map<String, dynamic> _buildTrojanOutbound(String url, String? sni, {String? resolvedIp}) {
    final uri = Uri.parse(url);
    final password = Uri.decodeComponent(uri.userInfo);
    final server = resolvedIp ?? uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    
    // TLS SNI uses whitelisted SNI if provided, otherwise original SNI
    final tlsSni = (sni != null && sni.isNotEmpty) ? sni : (query['sni'] ?? uri.host);
    // WebSocket Host MUST be the original server domain
    final httpHost = query['host'] ?? query['sni'] ?? uri.host;
    final type = query['type'] ?? 'tcp';

    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': server,
      'server_port': port,
      'password': password,
      'tls': {
        'enabled': true,
        'server_name': tlsSni,
        'utls': {
          'enabled': true,
          'fingerprint': 'chrome',
        },
        'insecure': true,
      },
    };

    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': query['path'] ?? '/',
        'headers': {'Host': httpHost},
      };
    }

    return outbound;
  }

  static Map<String, dynamic>? parseSshUrl(String url) {
    try {
      if (!url.startsWith('ssh://')) return null;
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 22;
      String username = '';
      String password = '';
      if (uri.userInfo.isNotEmpty) {
        final idx = uri.userInfo.indexOf(':');
        if (idx == -1) {
          username = Uri.decodeComponent(uri.userInfo);
        } else {
          username = Uri.decodeComponent(uri.userInfo.substring(0, idx));
          password = Uri.decodeComponent(uri.userInfo.substring(idx + 1));
        }
      }
      final query = uri.queryParameters;
      final useSsl = query['ssl'] == 'true' || query['tls'] == 'true' || port == 443;
      return {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'useSsl': useSsl,
        'sni': query['host'] ?? query['sni'] ?? '',
      };
    } catch (e) {
      print('Error parsing SSH URL: $e');
      return null;
    }
  }

  /// Fetches the SHA-256 fingerprint of a server's TLS certificate.
  /// Connects to [host]:[port] with SNI [sni], accepts any certificate,
  /// and returns the hex-encoded SHA-256 digest of the DER-encoded cert.
  static Future<String?> fetchCertSha256(
    String host,
    int port,
    String sni,
  ) async {
    try {
      final rawSocket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      final secureSocket = await SecureSocket.secure(
        rawSocket,
        host: sni,
        onBadCertificate: (X509Certificate cert) => true,
      );
      final derData = secureSocket.peerCertificate?.der;
      await secureSocket.close();
      if (derData != null) {
        return sha256.convert(derData).toString();
      }
    } catch (e) {
      print('fetchCertSha256 error: $e');
    }
    return null;
  }

  static String buildXrayConfig({
    required String serverUrl,
    String? sni,
    String? pinnedPeerCertSha256,
  }) {
    final uri = Uri.parse(serverUrl);
    final uuid = uri.userInfo;
    final host = uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    
    final security = query['security'] ?? 'none';
    final type = query['type'] ?? 'tcp';
    
    // Override SNI with the user's selected SNI if present
    final tlsSni = sni ?? query['sni'] ?? query['host'] ?? host;
    final wsHost = query['host'] ?? query['sni'] ?? host;
    final path = query['path'] ?? '/';

    final config = {
      "log": {
        "loglevel": "warning"
      },
      "inbounds": [
        {
          "port": 10808,
          "listen": "127.0.0.1",
          "protocol": "socks",
          "settings": {
            "udp": true
          }
        }
      ],
      "outbounds": [
        {
          "protocol": "vless",
          "settings": {
            "vnext": [
              {
                "address": host,
                "port": port,
                "users": [
                  {
                    "id": uuid,
                    "encryption": "none"
                  }
                ]
              }
            ]
          },
          "streamSettings": {
            "network": type,
            "security": security,
            if (security == 'tls')
              "tlsSettings": {
                "serverName": tlsSni,
                if (pinnedPeerCertSha256 != null && pinnedPeerCertSha256.isNotEmpty)
                  "pinnedPeerCertSha256": pinnedPeerCertSha256
              },
            if (security == 'reality')
              "realitySettings": {
                "show": false,
                "fingerprint": query['fp'] ?? "chrome",
                "serverName": tlsSni,
                "publicKey": query['pbk'] ?? "",
                "shortId": query['sid'] ?? "",
                "spiderX": ""
              },
            if (type == 'ws')
              "wsSettings": {
                "path": path,
                "headers": {
                  "Host": wsHost
                }
              }
          }
        }
      ]
    };

    return jsonEncode(config);
  }

  static String? getServerHost(String url) {
    try {
      if (url.startsWith('vmess://')) {
        final base64Str = url.substring('vmess://'.length);
        String normalized = base64Str;
        final mod = base64Str.length % 4;
        if (mod > 0) normalized += '=' * (4 - mod);
        final json = jsonDecode(utf8.decode(base64.decode(normalized)));
        return json['add'] as String?;
      } else if (url.startsWith('vless://') || url.startsWith('trojan://') || url.startsWith('ssh://') || url.startsWith('slowdns://')) {
        return Uri.parse(url).host;
      }
    } catch (_) {}
    return null;
  }
}
