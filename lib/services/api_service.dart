import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../data/servers.dart';

class ApiService {
  static const String _sniUrl = 'https://waledapis.vercel.app/api/sni';
  static const String _vlessUrl = 'https://waledapis.vercel.app/api/vless';
  static const String _sshUrl = 'https://waledapis.vercel.app/api/ssh';
  static const String _vmessUrl = 'https://waledapis.vercel.app/api/vmess';
  static const String _slowDnsUrl = 'https://waledapis.vercel.app/api/slowdns';

  static const String _secret = 'sk_wp_ffaf63dd7ee834efb691957c771998a29e9ae6b6dbc3c401efcfab1e9d886f05';

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

  static Future<List<SniProfile>> fetchSniProfiles() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_sniUrl), headers: headers);
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
    // Manual SSH server for testing
    final manualServer = VpnServer(
      name: 'Root SSH Test',
      url: 'ssh://root:${Uri.encodeComponent("?AM.81#Hs-LjVfG;\'P0f")}@187.127.107.105:443?ssl=true',
      icon: 'assets/images/server.svg',
    );

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_sshUrl), headers: headers);
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        final servers = data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty && server.url.startsWith('ssh://'))
            .toList();
        return [manualServer, ...servers];
      } else {
        return [manualServer];
      }
    } catch (e) {
      print('Error fetching SSH servers: $e');
      return [manualServer];
    }
  }

  static Future<List<VpnServer>> fetchVmessServers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_vmessUrl), headers: headers);
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
    // Manually add SlowDNS servers for testing
    final testServer = VpnServer(
      name: 'Test Manual SlowDNS',
      url: 'slowdns://cb296a077536ccf833fbb33d27aa02171cfd9b7c95c54f7fa585803d51e6f032@tns.waledssl.blog?dns_ip=105.203.254.140',
      icon: 'assets/images/server.svg',
    );
    final newServer = VpnServer(
      name: 'New Server Test',
      url: 'slowdns://c79371dde3413656fa22a7c1b7c2736bde6688e1cac6d710faeb5c4d9f09c508@tns.waledssl.blog?dns_ip=187.127.107.105',
      icon: 'assets/images/server.svg',
    );

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(_slowDnsUrl), headers: headers);
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        final servers = data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty && server.url.startsWith('slowdns://'))
            .toList();
        
        // Add test servers to the top of the list
        return [newServer, testServer, ...servers];
      } else {
        return [newServer, testServer];
      }
    } catch (e) {
      print('Error fetching SlowDNS servers: $e');
      return [newServer, testServer];
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
