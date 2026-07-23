import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceAuditResult {
  final bool isGenuine;
  final bool isEmulator;
  final bool isClonedApp;
  final bool isRooted;
  final String failReason;
  final Map<String, dynamic> details;

  DeviceAuditResult({
    required this.isGenuine,
    required this.isEmulator,
    required this.isClonedApp,
    required this.isRooted,
    this.failReason = '',
    required this.details,
  });
}

class DeviceAuthenticityService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const List<String> _knownEmulatorFiles = [
    '/dev/qemu_pipe',
    '/dev/socket/qemu_pipe',
    '/system/lib/libc_malloc_debug_qemu.so',
    '/sys/qemu_trace',
    '/system/bin/nox-prop',
    '/system/bin/droid4x-prop',
    '/system/bin/ttVM-prop',
    '/system/bin/andy-prop',
    '/system/bin/microvirt-prop',
    '/fstab.nox',
    '/init.nox.rc',
  ];

  static const List<String> _knownRootFiles = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
  ];

  /// Performs a thorough multi-layered audit to verify device authenticity
  static Future<DeviceAuditResult> auditDevice() async {
    final Map<String, dynamic> details = {};
    bool isEmulator = false;
    bool isCloned = false;
    bool isRooted = false;
    String failReason = '';

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      
      final fingerprint = androidInfo.fingerprint.toLowerCase();
      final model = androidInfo.model.toLowerCase();
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final hardware = androidInfo.hardware.toLowerCase();
      final board = androidInfo.board.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();
      final device = androidInfo.device.toLowerCase();
      final product = androidInfo.product.toLowerCase();
      final isPhysical = androidInfo.isPhysicalDevice;

      details['model'] = model;
      details['manufacturer'] = manufacturer;
      details['isPhysicalDevice'] = isPhysical;
      details['fingerprint'] = fingerprint;

      // 1. Hardware & Build properties check
      if (!isPhysical) {
        isEmulator = true;
        failReason = 'الجهاز مسجل كمحاكي (isPhysicalDevice = false)';
      } else if (fingerprint.contains('generic') ||
          fingerprint.contains('vbox') ||
          fingerprint.contains('sdk_gphone') ||
          fingerprint.contains('test-keys') ||
          model.contains('google_sdk') ||
          model.contains('emulator') ||
          model.contains('android sdk built for x86') ||
          manufacturer.contains('genymotion') ||
          manufacturer.contains('nox') ||
          manufacturer.contains('bluestacks') ||
          hardware.contains('goldfish') ||
          hardware.contains('vbox86') ||
          hardware.contains('nox') ||
          hardware.contains('ttvm') ||
          brand.startsWith('generic') && device.startsWith('generic') ||
          product == 'sdk' ||
          product.contains('sdk_x86') ||
          product.contains('vbox86p') ||
          board.contains('nox')) {
        isEmulator = true;
        failReason = 'بصمة العتاد تتطابق مع خصائص المحاكيات (NOX/LDPlayer/BlueStacks)';
      }

      // 2. File system checks for QEMU & Emulator drivers
      if (!isEmulator) {
        for (final path in _knownEmulatorFiles) {
          try {
            if (await File(path).exists()) {
              isEmulator = true;
              failReason = 'تم اكتشاف سائق محاكي في النظام ($path)';
              break;
            }
          } catch (_) {}
        }
      }

      // 3. Root / Hooking check
      for (final path in _knownRootFiles) {
        try {
          if (await File(path).exists()) {
            isRooted = true;
            break;
          }
        } catch (_) {}
      }

      // 4. App Cloning / Parallel Space Check
      try {
        final currentDir = Directory.current.path;
        if (currentDir.contains('/data/user/999/') ||
            currentDir.contains('/data/user/10/') ||
            currentDir.contains('parallel') ||
            currentDir.contains('dualapp') ||
            currentDir.contains('clone')) {
          isCloned = true;
          failReason = 'تم اكتشاف تشغيل التطبيق داخل بيئة مستنسخة (Parallel Space / Dual App)';
        }
      } catch (_) {}
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      if (!iosInfo.isPhysicalDevice) {
        isEmulator = true;
        failReason = 'iOS Simulator detected';
      }
    }

    final isGenuine = !isEmulator && !isCloned && !isRooted;

    return DeviceAuditResult(
      isGenuine: isGenuine,
      isEmulator: isEmulator,
      isClonedApp: isCloned,
      isRooted: isRooted,
      failReason: failReason,
      details: details,
    );
  }
}
