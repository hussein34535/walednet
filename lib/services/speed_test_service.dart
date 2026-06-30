import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class SpeedTestService {
  Future<String?> _resolveDomainWithDoh(String domain) async {
    final dnsIps = ['1.1.1.1', '1.0.0.1', '8.8.8.8', '8.8.4.4'];
    for (var dnsIp in dnsIps) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 4)
          ..badCertificateCallback = (cert, host, port) => true;
          
        final request = await client.getUrl(Uri.parse('https://$dnsIp/dns-query?name=$domain&type=A'));
        request.headers.set('accept', 'application/dns-json');
        
        final response = await request.close();
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(responseBody);
          final answers = data['Answer'] as List?;
          if (answers != null && answers.isNotEmpty) {
            for (var answer in answers) {
              if (answer['type'] == 1) { // A record
                return answer['data'].toString().trim();
              }
            }
          }
        }
      } catch (e) {
        print('[DoH Resolve] Failed for $dnsIp: $e');
      }
    }
    return null;
  }

  Future<double?> runDownloadTest() async {
    final ip = await _resolveDomainWithDoh('speed.cloudflare.com');
    if (ip == null) {
      print('[DownloadSpeedTest] DNS resolution failed');
      return -1;
    }
    
    print('[DownloadSpeedTest] Resolved speed.cloudflare.com to $ip');
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
        ..badCertificateCallback = (cert, host, port) => true;
        
      final request = await client.getUrl(Uri.parse('https://$ip/__down?bytes=5000000'));
      request.headers.set('Host', 'speed.cloudflare.com');
      
      final stopwatch = Stopwatch()..start();
      final response = await request.close().timeout(const Duration(seconds: 25));
      
      if (response.statusCode != 200) {
        print('[DownloadSpeedTest] HTTP status error: ${response.statusCode}');
        return -1;
      }
      
      final List<int> bytes = [];
      await for (var chunk in response) {
        bytes.addAll(chunk);
      }
      stopwatch.stop();
      
      final duration = stopwatch.elapsed;
      final contentLength = bytes.length;
      
      if (duration.inMilliseconds > 0 && contentLength > 0) {
        final speedBps = (contentLength * 8) / (duration.inMilliseconds / 1000);
        final speedMbps = speedBps / (1024 * 1024);
        print('[DownloadSpeedTest] Success: ${speedMbps.toStringAsFixed(2)} Mbps');
        return speedMbps;
      }
      return null;
    } catch (e) {
      print('[DownloadSpeedTest] Error: $e');
      return -1;
    }
  }

  Future<double?> runUploadTest() async {
    final ip = await _resolveDomainWithDoh('speed.cloudflare.com');
    if (ip == null) {
      print('[UploadSpeedTest] DNS resolution failed');
      return -1;
    }
    
    print('[UploadSpeedTest] Resolved speed.cloudflare.com to $ip');
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
        ..badCertificateCallback = (cert, host, port) => true;
        
      final request = await client.postUrl(Uri.parse('https://$ip/__up'));
      request.headers.set('Host', 'speed.cloudflare.com');
      
      final payloadSize = 1024 * 1024; // 1MB
      final dummyPayload = Uint8List(payloadSize);
      
      final stopwatch = Stopwatch()..start();
      request.add(dummyPayload);
      final response = await request.close().timeout(const Duration(seconds: 20));
      stopwatch.stop();
      
      final duration = stopwatch.elapsed;
      if (duration.inMilliseconds > 0 && response.statusCode == 200) {
        final speedBps = (payloadSize * 8) / (duration.inMilliseconds / 1000);
        final speedMbps = speedBps / (1024 * 1024);
        print('[UploadSpeedTest] Success: ${speedMbps.toStringAsFixed(2)} Mbps');
        return speedMbps;
      }
      return -1;
    } catch (e) {
      print('[UploadSpeedTest] Error: $e');
      return -1;
    }
  }
}
