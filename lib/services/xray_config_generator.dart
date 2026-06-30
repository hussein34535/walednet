import 'dart:convert';

class XrayConfigGenerator {
  /// تحويل رابط vless إلى إعدادات Xray للويندوز
  static String generateConfig(String url) {
    if (!url.startsWith('vless://')) {
      throw Exception('Only VLESS is currently supported in this generator');
    }

    // Example URL: vless://uuid@server:443?encryption=none&security=tls&type=ws&host=sni&path=/path#remark
    final uri = Uri.parse(url);
    final uuid = uri.userInfo;
    final serverIp = uri.host;
    final port = uri.port;

    final query = uri.queryParameters;
    final security = query['security'] ?? 'none';
    final type = query['type'] ?? 'tcp';
    final sni = query['sni'] ?? query['host'] ?? serverIp;
    final path = query['path'] ?? '/';

    final Map<String, dynamic> config = {
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
                "address": serverIp,
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
            "tlsSettings": security == 'tls' ? {
              "serverName": sni,
              "allowInsecure": true
            } : null,
            "wsSettings": type == 'ws' ? {
              "path": path,
              "headers": {
                "Host": sni
              }
            } : null
          }
        }
      ]
    };

    // Remove null values
    if (config['outbounds'][0]['streamSettings']['tlsSettings'] == null) {
      config['outbounds'][0]['streamSettings'].remove('tlsSettings');
    }
    if (config['outbounds'][0]['streamSettings']['wsSettings'] == null) {
      config['outbounds'][0]['streamSettings'].remove('wsSettings');
    }

    return jsonEncode(config);
  }
}
