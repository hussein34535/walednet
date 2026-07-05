import 'dart:convert';

class SingboxConfigBuilder {
  static String build({
    required String serverUrl,
    String? sni,
    String? sniProfileName,
  }) {
    final outbound = _buildOutbound(serverUrl, sni);
    final config = {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': {
        'servers': [
          {
            'tag': 'cloudflare',
            'address': 'https://1.1.1.1/dns-query',
            'detour': 'proxy',
          },
          {
            'tag': 'local',
            'address': 'local',
            'detour': 'direct',
          },
        ],
        'rules': [
          {
            'outbound': 'any',
            'server': 'local',
          },
        ],
        'strategy': 'ipv4_only',
        'fakeip': {
          'enabled': true,
          'inet4_range': '198.18.0.0/15',
        },
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'inet4_address': '172.19.0.1/30',
          'inet6_address': 'fdfe:dcba:9876::1/126',
          'mtu': 1500,
          'auto_route': true,
          'strict_route': true,
          'stack': 'system',
          'dns_hijack': [
            'tcp://any:53',
            'udp://any:53',
          ],
          'sniff': true,
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
        {
          'type': 'dns',
          'tag': 'dns-out',
        },
      ],
      'route': {
        'rules': [
          {
            'protocol': 'dns',
            'outbound': 'dns-out',
          },
          {
            'ip_is_private': true,
            'outbound': 'direct',
          },
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
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

  static Map<String, dynamic> _buildOutbound(String url, String? sni) {
    if (url.startsWith('vless://')) {
      return _buildVlessOutbound(url, sni);
    } else if (url.startsWith('vmess://')) {
      return _buildVmessOutbound(url, sni);
    } else if (url.startsWith('ssh://')) {
      return _buildSshOutbound(url, sni);
    } else if (url.startsWith('trojan://')) {
      return _buildTrojanOutbound(url, sni);
    }
    throw Exception('Unsupported protocol: $url');
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
      'network': type,
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
      'network': type,
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

  static Map<String, dynamic> _buildSshOutbound(String url, String? sni) {
    final uri = Uri.parse(url);
    final server = uri.host;
    final port = uri.port != 0 ? uri.port : 22;
    final username = Uri.decodeComponent(uri.userInfo.split(':')[0]);
    final password = uri.userInfo.contains(':')
        ? Uri.decodeComponent(uri.userInfo.split(':')[1])
        : '';
    final query = uri.queryParameters;
    final useSsl = query['ssl'] == 'true';

    final outbound = <String, dynamic>{
      'type': 'ssh',
      'tag': 'proxy',
      'server': server,
      'server_port': port,
      'user': username,
      'password': password,
    };

    if (useSsl) {
      final serverName = sni ?? query['host'] ?? server;
      outbound['tls'] = {
        'enabled': true,
        'server_name': serverName,
        'insecure': true,
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
      'network': type,
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
}
