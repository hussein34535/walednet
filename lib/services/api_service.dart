import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../data/servers.dart';

class ApiService {
  static const String _sniUrl = 'https://waledapis.vercel.app/api/sni';
  static const String _vlessUrl = 'https://waledapis.vercel.app/api/vless';
  static const String _sshUrl = 'https://waledapis.vercel.app/api/ssh';
  static const String _vmessUrl = 'https://waledapis.vercel.app/api/vmess';
  static const String _slowDnsUrl = 'https://waledapis.vercel.app/api/slowdns';

  // TODO: Rotate this secret on the server. Current one is exposed.
  // Move to server-side verification + rate limiting / Play Integrity.
  static const String _secret = 'sk_wp_2651d07e90ef42773428096a1b2cc5bce48eb1d34646bd3fa4dd55531bd7b38c';

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<Map<String, String>> _getHeaders() async {
    final Map<String, String> headers = Map.from(_headers);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      final key = utf8.encode(_secret);
      final bytes = utf8.encode(timestamp);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      
      headers['X-Auth-Token'] = '$timestamp.$digest';
    } catch (e) {
      print('[ApiService] Error generating HMAC token: $e');
    }
    return headers;
  }

  static Future<void> _logApi(String endpoint, int status, String body) async {
    try {
      await File(r'D:\WALEDNET\build\api_log.txt').writeAsString(
        '[${DateTime.now()}] $endpoint → $status\nBody: ${body.length > 2000 ? body.substring(0, 2000) : body}\n---\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  static Future<List<SniProfile>> fetchSniProfiles() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_sniUrl), headers: headers);
      await _logApi('SNI', response.statusCode, utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data.map((json) => SniProfile.fromJson(json)).where((profile) => profile.sni.isNotEmpty).toList();
      } else {
        throw Exception('Failed to load SNI profiles: status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching SNI profiles: $e');
      return [];
    }
  }

  static Future<List<VpnServer>> fetchVlessServers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_vlessUrl), headers: headers);
      await _logApi('VLESS', response.statusCode, utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load VLESS servers: status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching VLESS servers: $e');
      return [];
    }
  }

  static Future<List<VpnServer>> fetchSshServers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_sshUrl), headers: headers);
      await _logApi('SSH', response.statusCode, utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty && server.url.startsWith('ssh://'))
            .toList();
      } else {
        throw Exception('Failed to load SSH servers: status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching SSH servers: $e');
      return [];
    }
  }

  static Future<List<VpnServer>> fetchVmessServers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_vmessUrl), headers: headers);
      await _logApi('VMESS', response.statusCode, utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty && server.url.startsWith('vmess://'))
            .toList();
      } else {
        throw Exception('Failed to load VMESS servers: status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching VMESS servers: $e');
      return [];
    }
  }

  static Future<List<VpnServer>> fetchSlowDnsServers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_slowDnsUrl), headers: headers);
      await _logApi('SLOWDNS', response.statusCode, utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty && server.url.startsWith('slowdns://'))
            .toList();
      } else {
        throw Exception('Failed to load SlowDNS servers: status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching SlowDNS servers: $e');
      return [];
    }
  }

  static Future<bool> addSniProfile(String name, String host) async {
    try {
      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';
      
      final body = jsonEncode({
        'name': name,
        'host': host,
      });
      
      final response = await http.post(
        Uri.parse(_sniUrl),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[ApiService] SNI added successfully: ${response.body}');
        return true;
      } else {
        print('[ApiService] Failed to add SNI: status code ${response.statusCode}, body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[ApiService] Error adding SNI: $e');
      return false;
    }
  }
}
