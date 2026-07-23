import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/servers.dart';

class ServerFlagWidget extends StatelessWidget {
  final VpnServer server;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ServerFlagWidget({
    super.key,
    required this.server,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final flagUrl = server.flagUrl;
    final code = server.countryCode;

    // 1. Direct HTTP/HTTPS Remote Flag Image
    if (flagUrl != null && flagUrl.startsWith('http')) {
      if (flagUrl.endsWith('.svg')) {
        return SvgPicture.network(
          flagUrl,
          width: width,
          height: height,
          fit: fit,
          placeholderBuilder: (_) => _fallbackGlobe(),
        );
      }
      return Image.network(
        flagUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallbackGlobe(),
      );
    }

    // 2. Country Flag Rendering
    if (code != null && code.isNotEmpty) {
      const localCodes = {'de', 'us', 'mx', 'eg', 'fr', 'nl', 'it'};

      // Local SVG Asset (instant offline)
      if (localCodes.contains(code)) {
        return SvgPicture.asset(
          'assets/images/$code.svg',
          width: width,
          height: height,
          fit: fit,
        );
      }

      // Android / Mobile native high-res flag emoji (100% offline & instant)
      if (Platform.isAndroid || Platform.isIOS) {
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              countryCodeToEmoji(code),
              style: const TextStyle(fontSize: 22),
            ),
          ),
        );
      }

      // Desktop / Web FlagCDN fallback
      return Image.network(
        'https://flagcdn.com/w160/$code.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallbackGlobe(),
      );
    }

    return _fallbackGlobe();
  }

  static String countryCodeToEmoji(String code) {
    if (code.length != 2) return '🌐';
    final c1 = code.toLowerCase().codeUnitAt(0) - 0x61 + 0x1F1E6;
    final c2 = code.toLowerCase().codeUnitAt(1) - 0x61 + 0x1F1E6;
    return String.fromCharCode(c1) + String.fromCharCode(c2);
  }

  Widget _fallbackGlobe() {
    return SvgPicture.asset(
      'assets/images/global.svg',
      width: width,
      height: height,
      fit: fit,
    );
  }
}
