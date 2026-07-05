import 'dart:convert';

class SingboxConfigBuilder {
  static String build({
    required String serverUrl,
    String? sni,
    String? sniProfileName,
    int sshLocalPort = 10809,
  }) {
    final isSsh = serverUrl.startsWith('ssh://');
    final outbound = _buildOutbound(serverUrl, sni, sshLocalPort);
    final config = {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': {
        'servers': [
          {
            'type': 'udp',
            'tag': 'dns-remote',
            'server': '1.1.1.1',
            'server_port': 53,
          },
        ],
        'final': 'dns-remote',
        'strategy': 'ipv4_only',
        'independent_cache': true,
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'address': '172.19.0.1/30',
          'mtu': 1500,
          'auto_route': true,
          'stack': 'mixed',
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
        'rules': [
          {
            'action': 'sniff',
          },
          {
            'protocol': 'dns',
            'action': 'hijack-dns',
          },
          {
            'ip_is_private': true,
            'outbound': 'direct',
          },
        ],
        'auto_detect_interface': true,
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

  static Map<String, dynamic> _buildOutbound(String url, String? sni, int sshLocalPort) {
    if (url.startsWith('vless://')) {
      return _buildVlessOutbound(url, sni);
    } else if (url.startsWith('vmess://')) {
      return _buildVmessOutbound(url, sni);
    } else if (url.startsWith('ssh://')) {
      return _buildSshSocksOutbound(sshLocalPort);
    } else if (url.startsWith('trojan://')) {
      return _buildTrojanOutbound(url, sni);
    }
    throw Exception('Unsupported protocol: $url');
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

  static Map<String, dynamic> _buildVlessOutbound(String url, String? sni) {
    final uri = Uri.parse(url);
    final uuid = uri.userInfo;
    final server = uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    final security = query['security'] ?? 'none';
    final type = query['type'] ?? 'tcp';
    final serverName = sni ?? query['sni'] ?? query['host'] ?? server;
    final path = query['path'] ?? '/';
    final host = query['host'] ?? serverName;
    final flow = query['flow'];

    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'flow': flow,
    };

    if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': serverName,
        'utls': {
          'enabled': true,
          'fingerprint': 'chrome',
        },
        'insecure': true,
      };
    } else if (security == 'reality') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': serverName,
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
        'headers': {'Host': host},
      };
    } else if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': query['serviceName'] ?? '',
      };
    } else if (type == 'http') {
      outbound['transport'] = {
        'type': 'http',
        'host': [host],
        'path': path,
      };
    }

    return outbound;
  }

  static Map<String, dynamic> _buildVmessOutbound(String url, String? sni) {
    final base64Str = url.substring('vmess://'.length);
    String normalized = base64Str;
    final mod = base64Str.length % 4;
    if (mod > 0) normalized += '=' * (4 - mod);
    final json = jsonDecode(utf8.decode(base64.decode(normalized)));

    final server = json['add'] as String;
    final port = json['port'] as int;
    final uuid = json['id'] as String;
    final aid = (json['aid'] ?? 0) as int;
    final security = json['tls'] ?? '';
    final type = json['net'] ?? 'tcp';
    final serverName = sni ?? json['sni'] ?? json['host'] ?? server;
    final path = json['path'] ?? '/';
    final host = json['host'] ?? serverName;

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
        'server_name': serverName,
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
        'headers': {'Host': host},
      };
    } else if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': json['path'] ?? '',
      };
    }

    return outbound;
  }

  static Map<String, dynamic> _buildTrojanOutbound(String url, String? sni) {
    final uri = Uri.parse(url);
    final password = Uri.decodeComponent(uri.userInfo);
    final server = uri.host;
    final port = uri.port;
    final query = uri.queryParameters;
    final serverName = sni ?? query['sni'] ?? server;
    final type = query['type'] ?? 'tcp';

    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': server,
      'server_port': port,
      'password': password,
      'tls': {
        'enabled': true,
        'server_name': serverName,
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
        'headers': {'Host': query['host'] ?? serverName},
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
      return {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'useSsl': query['ssl'] == 'true',
        'sni': query['host'] ?? query['sni'] ?? '',
      };
    } catch (e) {
      print('Error parsing SSH URL: $e');
      return null;
    }
  }
}
