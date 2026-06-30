import 'dart:convert';

class SniProfile {
  final String name;
  final String sni;
  final String icon;

  SniProfile({
    required this.name,
    required this.sni,
    this.icon = 'assets/images/server.svg',
  });

  factory SniProfile.fromJson(Map<String, dynamic> json) {
    print('[SniProfile.fromJson] Input JSON: $json');
    String parsedName =
        json['name']?.toString() ?? json['id']?.toString() ?? 'Unnamed Profile';
    String parsedSni =
        json['sni']?.toString() ?? json['host']?.toString() ?? '';
    String parsedIcon = json['icon']?.toString() ?? 'assets/images/server.svg';
    print(
        '[SniProfile.fromJson] Parsed - Name: $parsedName, SNI: $parsedSni, Icon: $parsedIcon');
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
    print('[VpnServer.fromJson] Input JSON: $json');
    String configUrl = json['url']?.toString() ??
        json['config']?.toString() ??
        ''; // Prioritize 'url' from cache, then 'config' from API
    String serverName = json['server_name']?.toString() ??
        json['name']?.toString() ??
        'Unnamed Server'; // Prioritize 'server_name' from API, then 'name' from cache

    // Fallback to URL fragment or host if 'name' from cache is not available
    if (serverName == 'Unnamed Server' && configUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(configUrl);
        if (uri.hasFragment) {
          serverName = Uri.decodeComponent(uri.fragment);
        } else {
          serverName = uri.host.isNotEmpty ? uri.host : 'Unnamed Server';
        }
      } catch (e) {
        print("[VpnServer.fromJson] Error parsing URL for name: $e");
      }
    }
    String parsedIcon = json['icon']?.toString() ?? 'assets/images/server.svg';
    print(
        '[VpnServer.fromJson] Parsed - Name: $serverName, URL: $configUrl, Icon: $parsedIcon');
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

// The static lists below will be replaced by API calls.
// They are kept here temporarily to avoid breaking the UI during development.
final allSniProfiles = <SniProfile>[
  SniProfile(
    name: 'Loading...',
    sni: '',
    icon: 'assets/images/app.svg', // Placeholder icon
  ),
];

final allServers = <VpnServer>[
  VpnServer(name: 'Loading...', url: '', icon: 'assets/images/server.svg'),
];
