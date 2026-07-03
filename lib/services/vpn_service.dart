import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

class VpnService {
  late final V2ray? _flutterV2ray;
  static const _tunnelChannel = MethodChannel('com.waled.net/vpn_tunnel');

  VpnService({required void Function(V2RayStatus) onStatusChanged}) {
    if (Platform.isAndroid || Platform.isIOS) {
      _flutterV2ray = V2ray(onStatusChanged: onStatusChanged);
    } else {
      _flutterV2ray = null;
    }
  }

  Future<void> initializeV2Ray() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterV2ray?.initialize();
    }
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await _flutterV2ray?.requestPermission() ?? false;
    }
    return true;
  }

  Future<void> startV2Ray({
    required String remark,
    required String config,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
    int sshLocalPort = -1,
    List<String>? blockedApps,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterV2ray?.startV2Ray(
        remark: remark,
        config: config,
        bypassSubnets: bypassSubnets,
        proxyOnly: proxyOnly,
        sshLocalPort: sshLocalPort,
        blockedApps: blockedApps,
      );
    }
  }

  Future<void> stopV2Ray() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterV2ray?.stopV2Ray();
    }
  }

  Future<int> getServerDelay({required String config}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        return await _flutterV2ray?.getServerDelay(config: config) ?? -1;
      } catch (e) {
        print('[VpnService] Error getting server delay: $e');
        return -1;
      }
    }
    return -1;
  }

  Future<List<String>> getLogs() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        return await _flutterV2ray?.getLogs() ?? [];
      } catch (e) {
        print('[VpnService] Error getting logs: $e');
        return [];
      }
    }
    return [];
  }

  Future<bool> clearLogs() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        return await _flutterV2ray?.clearLogs() ?? true;
      } catch (e) {
        print('[VpnService] Error clearing logs: $e');
        return false;
      }
    }
    return true;
  }

  /// Start custom WaledVpnService TUN -> SOCKS5 bridge (Android only)
  Future<bool> startCustomTunnel({int socksPort = 10808, String socksHost = '127.0.0.1', String dnsServer = '1.1.1.1'}) async {
    if (!Platform.isAndroid) return false;
    try {
      await _tunnelChannel.invokeMethod('startTunnel', {
        'socksPort': socksPort,
        'socksHost': socksHost,
        'dnsServer': dnsServer,
      });
      return true;
    } catch (e) {
      print('[VpnService] Error starting custom tunnel: $e');
      return false;
    }
  }

  /// Stop custom WaledVpnService
  Future<void> stopCustomTunnel() async {
    if (!Platform.isAndroid) return;
    try {
      await _tunnelChannel.invokeMethod('stopTunnel');
    } catch (e) {
      print('[VpnService] Error stopping custom tunnel: $e');
    }
  }
}
