import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/servers.dart';

class ApiService {
  static const String _sniUrl = 'https://waledapis.vercel.app/api/sni';
  static const String _vlessUrl = 'https://waledapis.vercel.app/api/vless';

  static Future<List<SniProfile>> fetchSniProfiles() async {
    try {
      final response = await http.get(Uri.parse(_sniUrl));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data.map((json) => SniProfile.fromJson(json)).where((profile) => profile.sni.isNotEmpty).toList(); // Add filtering for empty SNI
      } else {
        throw Exception('Failed to load SNI profiles');
      }
    } catch (e) {
      print('Error fetching SNI profiles: $e');
      return [];
    }
  }

  static Future<List<VpnServer>> fetchVlessServers() async {
    try {
      final response = await http.get(Uri.parse(_vlessUrl));
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data
            .map((json) => VpnServer.fromJson(json))
            .where((server) => server.url.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load VLESS servers');
      }
    } catch (e) {
      print('Error fetching VLESS servers: $e');
      return [];
    }
  }
}
