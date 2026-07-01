import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:WaledNet/data/servers.dart';

class UrlParserService {
  /// حقن SNI في رابط vmess المشفر بـ Base64
  static String injectVmessSni(String vmessUrl, String sni) {
    try {
      final base64Part = vmessUrl.substring(8).trim();
      String normalizedBase64 = base64Part;
      int mod = base64Part.length % 4;
      if (mod > 0) {
        normalizedBase64 += '=' * (4 - mod);
      }
      final decodedBytes = base64.decode(normalizedBase64);
      final decodedStr = utf8.decode(decodedBytes);
      final Map<String, dynamic> json = jsonDecode(decodedStr);

      json['sni'] = sni;
      json['host'] = sni;

      final reencodedStr = jsonEncode(json);
      final reencodedBytes = utf8.encode(reencodedStr);
      final reencodedBase64 = base64.encode(reencodedBytes);
      return 'vmess://$reencodedBase64';
    } catch (e) {
      print("[VMess SNI Inject] Error: $e");
      return vmessUrl;
    }
  }

  /// تحليل رابط SSH واستخراج بيانات الاعتماد والإعدادات
  static Map<String, dynamic>? parseSshUrl(String url) {
    try {
      if (!url.startsWith('ssh://')) return null;
      final uri = Uri.parse(url);

      final String host = uri.host;
      final int port = uri.port != 0 ? uri.port : 22;

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

      final bool useWs = uri.queryParameters['ws'] == 'true';
      final bool useSsl = uri.queryParameters['ssl'] == 'true';
      final String wsPath = uri.queryParameters['ws_path'] ?? '/';

      return {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'useWs': useWs,
        'useSsl': useSsl,
        'wsPath': wsPath,
      };
    } catch (e) {
      print("Error parsing SSH URL: $e");
      return null;
    }
  }

  /// ترجمة الدومين إلى IP (مع دعم DNS Lookup و DoH كخيار احتياطي)
  static Future<String> resolveDomain(String domain) async {
    try {
      final list = await InternetAddress.lookup(domain)
          .timeout(const Duration(seconds: 2));
      if (list.isNotEmpty) {
        return list.first.address;
      }
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=A'),
        headers: {'accept': 'application/dns-json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          for (var answer in answers) {
            if (answer['type'] == 1) {
              return answer['data'].toString().trim();
            }
          }
        }
      }
    } catch (_) {}

    if (domain == 'waled.online') {
      return '72.62.236.79';
    }

    return domain;
  }

  /// استبدال الهوست بالـ IP الخاص به في الرابط
  static Future<String> resolveUrlHost(String url) async {
    try {
      if (url.isEmpty) return url;
      if (url.startsWith('vmess://')) return url;
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return url;

      if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
        return url;
      }

      final ip = await resolveDomain(host);
      if (ip == host) return url;

      final updatedUri = uri.replace(host: ip);
      return updatedUri.toString();
    } catch (e) {
      print("Error resolving URL host: $e");
      return url;
    }
  }

  /// الحصول على الرابط النهائي للسيرفر مع دمج الـ SNI profile
  static String getFinalUrlForServer(VpnServer server, SniProfile? selectedProfile) {
    if (server.url.isEmpty) return '';
    String finalUrl = server.url;
    if (selectedProfile != null) {
      if (finalUrl.startsWith('vmess://') && !finalUrl.contains('?')) {
        return injectVmessSni(finalUrl, selectedProfile.sni);
      } else {
        try {
          Uri originalUri = Uri.parse(finalUrl);
          var queryParams =
              Map<String, String>.from(originalUri.queryParameters);
          queryParams['host'] = selectedProfile.sni;
          queryParams['sni'] = selectedProfile.sni;
          finalUrl =
              originalUri.replace(queryParameters: queryParams).toString();
        } catch (e) {
          print("Error in getFinalUrlForServer: $e");
        }
      }
    }
    return finalUrl;
  }

  /// توليد إعدادات V2Ray لربطها بالبروكسي المحلي الخاص بنفق SSH
  static Map<String, dynamic> generateSocksV2rayConfig(String sshHost) {
    if (Platform.isAndroid || Platform.isIOS) {
      return {
        "log": {"loglevel": "warning"},
        "dns": {
          "servers": ["1.1.1.1", "8.8.8.8"]
        },
        "inbounds": [
          {
            "tag": "socks-in",
            "protocol": "socks",
            "listen": "0.0.0.0",
            "port": 10808,
            "settings": {"udp": true}
          }
        ],
        "outbounds": [
          {
            "protocol": "socks",
            "tag": "proxy",
            "settings": {
              "servers": [
                {"address": "127.0.0.1", "port": 10809}
              ]
            }
          },
          {"protocol": "freedom", "tag": "direct", "settings": {}}
        ],
        "routing": {
          "domainStrategy": "AsIs",
          "rules": [
            {
              "type": "field",
              "ip": [sshHost],
              "outboundTag": "direct"
            },
            {
              "type": "field",
              "domain": [sshHost],
              "outboundTag": "direct"
            },
            {
              "type": "field",
              "port": 53,
              "network": "udp",
              "outboundTag": "direct"
            }
          ]
        }
      };
    }
    // Windows: keeps original SOCKS inbound + tun2socks approach
    return {
      "log": {"loglevel": "warning"},
      "dns": {
        "servers": ["1.1.1.1", "8.8.8.8"]
      },
      "inbounds": [
        {
          "port": 10808,
          "protocol": "socks",
          "listen": "0.0.0.0",
          "settings": {"auth": "noauth", "udp": true}
        }
      ],
      "outbounds": [
        {
          "protocol": "socks",
          "tag": "proxy",
          "settings": {
            "servers": [
              {"address": "127.0.0.1", "port": 10809}
            ]
          }
        },
        {"protocol": "freedom", "tag": "direct", "settings": {}}
      ],
      "routing": {
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "ip": [sshHost],
            "outboundTag": "direct"
          },
          {
            "type": "field",
            "domain": [sshHost],
            "outboundTag": "direct"
          },
          {
            "type": "field",
            "port": 53,
            "network": "udp",
            "outboundTag": "direct"
          }
        ]
      }
    };
  }

  /// جلب الـ IP من خلال البروكسي المحلي للـ VPN/SSH لتأكيد تغيير الـ IP
  static Future<String?> fetchIpThroughProxy() async {
    for (int port in [10808, 10809]) {
      try {
        final socket = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(seconds: 3));
        
        final completer = Completer<String?>();
        var state = 0; // 0: greeting, 1: connect, 2: http response
        final responseData = BytesBuilder();
        
        socket.listen(
          (data) {
            if (state == 0) {
              if (data.length >= 2 && data[0] == 0x05 && data[1] == 0x00) {
                state = 1;
                final hostBytes = utf8.encode('api.ipify.org');
                final req = BytesBuilder();
                req.add([0x05, 0x01, 0x00, 0x03, hostBytes.length]);
                req.add(hostBytes);
                req.add([0x00, 0x50]); // Port 80
                socket.add(req.takeBytes());
              } else {
                print('[fetchIpThroughProxy] Port $port: SOCKS5 greeting failed, unexpected response: $data');
                completer.complete(null);
                socket.destroy();
              }
            } else if (state == 1) {
              if (data.length >= 2 && data[0] == 0x05 && data[1] == 0x00) {
                state = 2;
                final httpRequest = 'GET /?format=json HTTP/1.1\r\n'
                    'Host: api.ipify.org\r\n'
                    'Connection: close\r\n\r\n';
                socket.add(utf8.encode(httpRequest));
              } else {
                print('[fetchIpThroughProxy] Port $port: CONNECT response failed: $data');
                completer.complete(null);
                socket.destroy();
              }
            } else if (state == 2) {
              responseData.add(data);
            }
          },
          onError: (e) {
            print('[fetchIpThroughProxy] Port $port: Stream error: $e');
            if (!completer.isCompleted) completer.complete(null);
            socket.destroy();
          },
          onDone: () {
            if (!completer.isCompleted) {
              try {
                final httpResponse = utf8.decode(responseData.takeBytes());
                final bodyStart = httpResponse.indexOf('{');
                if (bodyStart != -1) {
                  final body = httpResponse.substring(bodyStart);
                  final json = jsonDecode(body);
                  completer.complete(json['ip']?.toString());
                } else {
                  print('[fetchIpThroughProxy] Port $port: No JSON body in HTTP response');
                  completer.complete(null);
                }
              } catch (e) {
                print('[fetchIpThroughProxy] Port $port: Parse error: $e');
                completer.complete(null);
              }
            }
            socket.destroy();
          }
        );
        
        socket.add([0x05, 0x01, 0x00]);
        
        final ip = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
          print('[fetchIpThroughProxy] Port $port: SOCKS5 request timed out (5s)');
          return null;
        });
        if (ip != null) {
          print('[fetchIpThroughProxy] Successfully fetched IP $ip via SOCKS port $port');
          return ip;
        }
      } catch (e) {
        print('[fetchIpThroughProxy] Port $port: Connection failed: $e');
      }
    }
    return null;
  }
}
