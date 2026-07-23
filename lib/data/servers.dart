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

extension VpnServerFlagExtension on VpnServer {
  /// Extract ISO country code safely from Emoji Flag or Name keywords
  String? get countryCode {
    // 1. Universal scan for Unicode Regional Indicator Symbols (Emoji Flags for ALL 250 countries)
    try {
      final runesList = name.runes.toList();
      for (int i = 0; i < runesList.length - 1; i++) {
        final r1 = runesList[i];
        final r2 = runesList[i + 1];
        if (r1 >= 0x1F1E6 && r1 <= 0x1F1FF && r2 >= 0x1F1E6 && r2 <= 0x1F1FF) {
          final c1 = String.fromCharCode(r1 - 0x1F1E6 + 0x61);
          final c2 = String.fromCharCode(r2 - 0x1F1E6 + 0x61);
          return '$c1$c2'; // returns 'it', 'fr', 'us', 'de', 'es', 'eg', 'mx', etc.
        }
      }
    } catch (_) {}

    // 2. Keyword fallback for country names in Arabic and English
    final lower = name.toLowerCase();
    if (lower.contains('إيطاليا') || lower.contains('italy') || lower.contains('it')) return 'it';
    if (lower.contains('فرنسا') || lower.contains('france') || lower.contains('fr')) return 'fr';
    if (lower.contains('أمريكا') || lower.contains('usa') || lower.contains('us')) return 'us';
    if (lower.contains('ألمانيا') || lower.contains('germany') || lower.contains('de')) return 'de';
    if (lower.contains('مكسيك') || lower.contains('mexico') || lower.contains('mx')) return 'mx';
    if (lower.contains('مصر') || lower.contains('egypt') || lower.contains('eg')) return 'eg';
    if (lower.contains('هولندا') || lower.contains('netherlands') || lower.contains('nl')) return 'nl';
    if (lower.contains('إسبانيا') || lower.contains('spain') || lower.contains('es')) return 'es';
    if (lower.contains('تركيا') || lower.contains('turkey') || lower.contains('tr')) return 'tr';
    if (lower.contains('البرازيل') || lower.contains('brazil') || lower.contains('br')) return 'br';
    if (lower.contains('السعودية') || lower.contains('saudi') || lower.contains('sa')) return 'sa';
    if (lower.contains('الإمارات') || lower.contains('uae') || lower.contains('ae')) return 'ae';
    if (lower.contains('كندا') || lower.contains('canada') || lower.contains('ca')) return 'ca';
    if (lower.contains('اليابان') || lower.contains('japan') || lower.contains('jp')) return 'jp';
    if (lower.contains('بريطانيا') || lower.contains('uk') || lower.contains('gb')) return 'gb';
    if (lower.contains('الهند') || lower.contains('india') || lower.contains('in')) return 'in';
    if (lower.contains('الصين') || lower.contains('china') || lower.contains('cn')) return 'cn';
    if (lower.contains('روسيا') || lower.contains('russia') || lower.contains('ru')) return 'ru';
    if (lower.contains('السويد') || lower.contains('sweden') || lower.contains('se')) return 'se';
    if (lower.contains('سويسرا') || lower.contains('switzerland') || lower.contains('ch')) return 'ch';
    if (lower.contains('سنغافورة') || lower.contains('singapore') || lower.contains('sg')) return 'sg';

    return null;
  }

  /// Flag SVG Asset or CDN URL
  String get flagAsset {
    final code = countryCode;
    if (code != null && code.isNotEmpty) {
      const localSvgCodes = {'de', 'us', 'mx', 'eg', 'fr', 'nl', 'it'};
      if (localSvgCodes.contains(code)) {
        return 'assets/images/$code.svg';
      }
    }
    return 'assets/images/global.svg';
  }

  /// Returns flag URL if icon field is a remote URL
  String? get flagUrl {
    if (icon.startsWith('http://') || icon.startsWith('https://')) {
      return icon;
    }
    return null;
  }

  /// Returns clean server name without leading/trailing flag emojis safely
  String get cleanName {
    try {
      final buffer = StringBuffer();
      final runesList = name.runes.toList();
      for (int i = 0; i < runesList.length; i++) {
        final r = runesList[i];
        if (r >= 0x1F1E6 && r <= 0x1F1FF) continue; // Skip flag emoji runes
        buffer.writeCharCode(r);
      }
      final cleaned = buffer.toString().trim();
      return _toSafeUtf16(cleaned.isNotEmpty ? cleaned : name);
    } catch (_) {
      return _toSafeUtf16(name);
    }
  }
}

String _toSafeUtf16(String str) {
  // Strip any isolated UTF-16 surrogate code units that cause "not well-formed UTF-16"
  return str.replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
}

// Fallback lists when API calls are unavailable or unauthorized
final allSniProfiles = <SniProfile>[];

final allServers = <VpnServer>[];
