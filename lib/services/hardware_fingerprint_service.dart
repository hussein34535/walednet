import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareFingerprintService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const String _appSalt = 'WaledNet_HW_Salt_v2_2026_SecureKey#9912';

  /// Generates a unique, cryptographically signed hardware fingerprint string
  static Future<String> generateFingerprint() async {
    final StringBuffer rawPayload = StringBuffer();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        rawPayload.write('id:${androidInfo.id};');
        rawPayload.write('board:${androidInfo.board};');
        rawPayload.write('brand:${androidInfo.brand};');
        rawPayload.write('device:${androidInfo.device};');
        rawPayload.write('hardware:${androidInfo.hardware};');
        rawPayload.write('manufacturer:${androidInfo.manufacturer};');
        rawPayload.write('model:${androidInfo.model};');
        rawPayload.write('product:${androidInfo.product};');
        rawPayload.write('fingerprint:${androidInfo.fingerprint};');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        rawPayload.write('identifier:${iosInfo.identifierForVendor};');
        rawPayload.write('model:${iosInfo.model};');
        rawPayload.write('name:${iosInfo.name};');
        rawPayload.write('systemVersion:${iosInfo.systemVersion};');
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        rawPayload.write('deviceId:${windowsInfo.deviceId};');
        rawPayload.write('computerName:${windowsInfo.computerName};');
        rawPayload.write('numberOfCores:${windowsInfo.numberOfCores};');
      }
    } catch (_) {}

    // Sign payload with SHA-256 HMAC using internal app salt
    final key = utf8.encode(_appSalt);
    final bytes = utf8.encode(rawPayload.toString());
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return digest.toString();
  }
}
