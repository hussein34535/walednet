import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class WindowsVpnManager {
  static const String tun2socksUrl = 'https://github.com/xjasonlyu/tun2socks/releases/latest/download/tun2socks-windows-amd64.exe';
  static const String wintunUrl = 'https://www.wintun.net/builds/wintun-0.14.1.zip';
  static const String xrayUrl = 'https://github.com/XTLS/Xray-core/releases/latest/download/Xray-windows-64.zip';

  static Process? _xrayProcess;

  static Future<String> get _binDir async {
    final appDir = await getApplicationSupportDirectory();
    final binDir = Directory('${appDir.path}\\bin');
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }
    return binDir.path;
  }

  /// التحقق من وجود الأدوات، وتنزيلها وفك ضغطها إن لزم الأمر
  static Future<void> ensureBinaries() async {
    final binPath = await _binDir;
    final tun2socksFile = File('$binPath\\tun2socks.exe');
    final wintunDll = File('$binPath\\wintun.dll');
    final xrayExe = File('$binPath\\xray.exe');

    if (!await tun2socksFile.exists()) {
      print('[WindowsVpnManager] Downloading tun2socks...');
      final response = await http.get(Uri.parse(tun2socksUrl));
      if (response.statusCode == 200) {
        await tun2socksFile.writeAsBytes(response.bodyBytes);
      }
    }

    if (!await wintunDll.exists()) {
      print('[WindowsVpnManager] Downloading wintun...');
      final zipPath = '$binPath\\wintun.zip';
      final response = await http.get(Uri.parse(wintunUrl));
      if (response.statusCode == 200) {
        await File(zipPath).writeAsBytes(response.bodyBytes);
        await Process.run('powershell', [
          '-Command',
          'Expand-Archive -Path "$zipPath" -DestinationPath "$binPath\\wintun" -Force'
        ]);
        final extractedDll = File('$binPath\\wintun\\wintun\\bin\\amd64\\wintun.dll');
        if (await extractedDll.exists()) {
          await extractedDll.copy(wintunDll.path);
        }
      }
    }

    if (!await xrayExe.exists()) {
      print('[WindowsVpnManager] Downloading Xray...');
      final zipPath = '$binPath\\xray.zip';
      final response = await http.get(Uri.parse(xrayUrl));
      if (response.statusCode == 200) {
        await File(zipPath).writeAsBytes(response.bodyBytes);
        await Process.run('powershell', [
          '-Command',
          'Expand-Archive -Path "$zipPath" -DestinationPath "$binPath" -Force'
        ]);
      }
    }
  }

  /// تشغيل الـ VPN
  /// بالنسبة للـ VLESS سيقوم بتشغيل xray وتوجيه tun2socks لمنفذه (10808)
  /// بالنسبة للـ SSH سيتصل tun2socks بمنفذ النفق (10809)
  static Future<void> startVpn({
    required String type,
    required String serverIp,
    String? xrayConfigJson,
  }) async {
    await ensureBinaries();

    final binPath = await _binDir;
    
    int socksPort = 10809; // Default for SSH SOCKS5

    if (type.toLowerCase() == 'vless' && xrayConfigJson != null) {
      socksPort = 10808; // Xray port
      final configFile = File('$binPath\\config.json');
      await configFile.writeAsString(xrayConfigJson);

      print('[WindowsVpnManager] Starting Xray...');
      _xrayProcess = await Process.start('$binPath\\xray.exe', ['-config', configFile.path]);
    }

    print('[WindowsVpnManager] Starting tun2socks...');
    final tun2socksPath = '$binPath\\tun2socks.exe';
    
    // سكريبت يتم تشغيله بالكامل كمسؤول (RunAs) لضبط كارت الشبكة ومسارات التوجيه
    final script = '''
      # 1. تشغيل tun2socks بالخلفية
      Start-Process -FilePath "$tun2socksPath" -WorkingDirectory "$binPath" -ArgumentList "-device wintun -proxy socks5://127.0.0.1:$socksPort" -WindowStyle Hidden
      
      # الانتظار لتهيئة كارت الشبكة الوهمي
      Start-Sleep -Seconds 4
      
      # 2. تعيين عنوان IP لكارت الشبكة الوهمي (wintun) وتعيين العبارة الافتراضية
      netsh interface ipv4 set address name="wintun" source=static addr=192.168.123.1 mask=255.255.255.0 gateway=192.168.123.2
      
      # 3. تعيين DNS لمنع التسريب
      netsh interface ipv4 set dns name="wintun" source=static addr=1.1.1.1 register=primary
      
      # 4. رفع أولوية كارت الشبكة الوهمي عبر تقليل الـ Metric
      netsh interface ipv4 set interface "wintun" metric=5
      
      # 5. استثناء خادم الـ VPN لمنع حدوث Routing Loop
      \$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -ExpandProperty NextHop -First 1)
      if (\$gateway) {
          route add $serverIp mask 255.255.255.255 \$gateway metric 1
      }
    ''';

    final tempScript = File('$binPath\\start_vpn.ps1');
    await tempScript.writeAsString(script);
    
    // تشغيل السكريبت بالكامل كمسؤول
    await Process.run('powershell', [
      '-Command',
      'Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File \`"${tempScript.path}\`"" -Verb RunAs -WindowStyle Hidden'
    ]);
  }

  /// إيقاف كافة برامج النفق والتوجيهات
  static Future<void> stopVpn(String serverIp) async {
    _xrayProcess?.kill();
    _xrayProcess = null;

    final binPath = await _binDir;
    final script = '''
      taskkill /F /IM xray.exe
      taskkill /F /IM tun2socks.exe
      route delete $serverIp
    ''';

    final tempScript = File('$binPath\\stop_vpn.ps1');
    await tempScript.writeAsString(script);

    // تشغيل الحذف والإغلاق كمسؤول
    await Process.run('powershell', [
      '-Command',
      'Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File \`"${tempScript.path}\`"" -Verb RunAs -WindowStyle Hidden'
    ]);
    
    print('[WindowsVpnManager] VPN and routing fully stopped.');
  }
}
