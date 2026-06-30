import 'package:flutter_v2ray/flutter_v2ray.dart';

class VpnService {
  late final FlutterV2ray _flutterV2ray;

  VpnService({required void Function(V2RayStatus) onStatusChanged}) {
    _flutterV2ray = FlutterV2ray(onStatusChanged: onStatusChanged);
  }

  Future<void> initializeV2Ray() async {
    await _flutterV2ray.initializeV2Ray();
  }

  Future<bool> requestPermission() async {
    return await _flutterV2ray.requestPermission();
  }

  Future<void> startV2Ray({
    required String remark,
    required String config,
  }) async {
    await _flutterV2ray.startV2Ray(
      remark: remark,
      config: config,
    );
  }

  Future<void> stopV2Ray() async {
    await _flutterV2ray.stopV2Ray();
  }

  Future<int> getServerDelay({required String config}) async {
    try {
      return await _flutterV2ray.getServerDelay(config: config);
    } catch (e) {
      print('[VpnService] Error getting server delay: $e');
      return -1;
    }
  }
}
