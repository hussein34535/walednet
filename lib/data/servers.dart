class SniProfile {
  final String name;
  final String sni;
  final String icon;

  SniProfile({
    required this.name,
    required this.sni,
    this.icon = 'assets/images/server.svg',
  });

  String get displayName {
    if (sni.isEmpty) return name;
    final clean = name.replaceAll(RegExp(r'[?�\ufffd]'), ' ').trim();
    if (clean.length > 2) return clean;
    if (sni.length > 2) return sni;
    return name;
  }

  factory SniProfile.fromJson(Map<String, dynamic> json) {
    String parsedName =
        json['name']?.toString() ?? json['id']?.toString() ?? 'Unnamed Profile';
    String parsedSni =
        json['sni']?.toString() ?? json['host']?.toString() ?? '';
    String parsedIcon = json['icon']?.toString() ?? 'assets/images/server.svg';
    return SniProfile(
      name: parsedName,
      sni: parsedSni,
      icon: parsedIcon,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sni': sni, // Should not be null at this point
        'icon': icon,
      };
}

class VpnServer {
  final String name;
  final String url;
  final String icon;

  VpnServer({required this.name, required this.url, required this.icon});

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    String configUrl = json['url']?.toString() ??
        json['config']?.toString() ?? '';

    if ((json['type'] == 'SSH' || json['type'] == 'ssh') && !configUrl.startsWith('ssh://')) {
      final ip = json['ip_address']?.toString() ?? '';
      final user = json['username']?.toString() ?? '';
      final pass = json['password']?.toString() ?? '';
      String port = '443';
      if (configUrl.contains(':')) {
        final beforeAt = configUrl.split('@')[0];
        final parts = beforeAt.split(':');
        if (parts.length > 1) port = parts[1];
      }
      if (ip.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
        configUrl = 'ssh://$user:$pass@$ip:$port?ssl=${port == '443' ? 'true' : 'false'}';
      }
    }

    if ((json['type'] == 'SLOWDNS' || json['type'] == 'slowdns') && !configUrl.startsWith('slowdns://')) {
      final pubKey = json['public_key']?.toString() ?? '';
      final ns = json['ns']?.toString() ?? '';
      final dnsIp = json['dns_ip']?.toString() ?? '';
      if (pubKey.isNotEmpty && ns.isNotEmpty) {
        configUrl = 'slowdns://$pubKey@$ns?dns_ip=$dnsIp';
      }
    }

    String serverName = json['server_name']?.toString() ??
        json['name']?.toString() ??
        'Unnamed Server';

    if (serverName == 'Unnamed Server' && configUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(configUrl);
        if (uri.hasFragment) {
          serverName = Uri.decodeComponent(uri.fragment);
        } else {
          serverName = uri.host.isNotEmpty ? uri.host : 'Unnamed Server';
        }
      } catch (e) {
        // keep default name
      }
    }
    String parsedIcon = json['icon']?.toString() ?? 'assets/images/server.svg';
    return VpnServer(
      name: serverName,
      url: configUrl,
      icon: parsedIcon,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url, // Should not be null at this point
        'icon': icon,
      };
}

// Fallback lists when API calls are unavailable or unauthorized
final allSniProfiles = <SniProfile>[];

final allServers = <VpnServer>[];
