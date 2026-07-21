import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleAuthResult {
  final String idToken;
  final String? photoUrl;
  final String? name;
  final String? email;

  GoogleAuthResult({
    required this.idToken,
    this.photoUrl,
    this.name,
    this.email,
  });
}

class _DotEnv {
  static Map<String, String>? _cached;

  static String? _decodeBase64(String value) {
    try {
      final normalized = value.padRight(value.length + (4 - value.length % 4) % 4, '=');
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _load() {
    if (_cached != null) return _cached!;
    _cached = {};
    try {
      final file = File('.env');
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final eq = trimmed.indexOf('=');
          if (eq < 1) continue;
          final key = trimmed.substring(0, eq).trim();
          final value = trimmed.substring(eq + 1).trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            _cached![key] = _decodeBase64(value) ?? value;
          }
        }
      }
    } catch (_) {}
    return _cached!;
  }
}

class GoogleWindowsAuth {
  static String get _clientId =>
      Platform.environment['GOOGLE_OAUTH_CLIENT_ID'] ??
      _DotEnv._load()['GOOGLE_OAUTH_CLIENT_ID'] ??
      '';
  static String get _clientSecret =>
      Platform.environment['GOOGLE_OAUTH_CLIENT_SECRET'] ??
      _DotEnv._load()['GOOGLE_OAUTH_CLIENT_SECRET'] ??
      '';
  static const String _tokenEndpoint =
      'https://oauth2.googleapis.com/token';
  static const String _authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const int _port = 8080;
  static const String _charset =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (i) => _charset.codeUnitAt(random.nextInt(_charset.length)));
    return String.fromCharCodes(bytes);
  }

  static String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<GoogleAuthResult?> signIn() async {
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      debugPrint('[GoogleWindowsAuth] Missing GOOGLE_OAUTH_CLIENT_ID or GOOGLE_OAUTH_CLIENT_SECRET env vars');
      return null;
    }
    final redirectUri = 'http://localhost:$_port';
    final state = _generateState();
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid profile email',
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
    final codeCompleter = Completer<HttpRequest>();

    unawaited(
      _handleCallback(server, state, codeCompleter),
    );

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      server.close();
      return null;
    }

    try {
      final request = await codeCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('انتهت مهلة تسجيل الدخول'),
      );
      final code = request.uri.queryParameters['code']!;
      debugPrint('[GoogleWindowsAuth] Code received, exchanging for token...');
      final result = await _exchangeCode(code, redirectUri, codeVerifier);
      debugPrint('[GoogleWindowsAuth] Exchange result: ${result != null ? "SUCCESS" : "FAILED"}');
      if (result != null) {
        _respond(request, 200, 'تم تسجيل الدخول بنجاح!');
      } else {
        _respond(request, 500, 'فشل تسجيل الدخول. حاول مرة أخرى.');
      }
      return result;
    } finally {
      server.close();
    }
  }

  static Future<void> _handleCallback(
    HttpServer server,
    String expectedState,
    Completer<HttpRequest> requestCompleter,
  ) async {
    try {
      await for (final request in server) {
        if (request.uri.queryParameters.containsKey('code')) {
          final state = request.uri.queryParameters['state'];
          if (state != expectedState) {
            _respond(request, 400, 'State mismatch - طلب غير صالح');
            requestCompleter.completeError(Exception('State mismatch'));
            return;
          }
          requestCompleter.complete(request);
          return;
        } else if (request.uri.queryParameters.containsKey('error')) {
          _respond(request, 400, 'تم إلغاء تسجيل الدخول');
          requestCompleter.completeError(Exception('تم إلغاء تسجيل الدخول'));
          return;
        }
        _respond(request, 404, 'Not Found');
      }
    } catch (e) {
      if (!requestCompleter.isCompleted) {
        requestCompleter.completeError(e);
      }
    }
  }

  static void _respond(HttpRequest request, int status, String body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.html;
    request.response.write('''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WaledNet VPN</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Tahoma, sans-serif;
    background: linear-gradient(135deg, #0a0e27 0%, #1a1040 50%, #0d1b3e 100%);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .card {
    background: rgba(255,255,255,0.05);
    backdrop-filter: blur(20px);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 24px;
    padding: 48px 40px;
    max-width: 420px;
    width: 100%;
    text-align: center;
  }
  .icon {
    width: 72px;
    height: 72px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 24px;
    font-size: 36px;
  }
  .icon.success { background: rgba(52,199,89,0.15); color: #34c759; }
  .icon.error { background: rgba(255,69,58,0.15); color: #ff453a; }
  h1 {
    color: #fff;
    font-size: 22px;
    font-weight: 700;
    margin-bottom: 12px;
  }
  p {
    color: rgba(255,255,255,0.6);
    font-size: 15px;
    line-height: 1.6;
    margin-bottom: 8px;
  }
  .spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(255,255,255,0.1);
    border-top-color: #34c759;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 24px auto 0;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
</head>
<body>
  <div class="card">
    <div class="icon ${status == 200 ? 'success' : 'error'}">
      ${status == 200 ? '✓' : '✗'}
    </div>
    <h1>${status == 200 ? 'تم تسجيل الدخول بنجاح' : 'فشل تسجيل الدخول'}</h1>
    <p>${body}</p>
    <p style="font-size:13px;color:rgba(255,255,255,0.35)">يمكنك إغلاق هذه الصفحة والعودة للتطبيق</p>
    <div class="spinner"></div>
  </div>
  <script>setTimeout(() => window.close(), 3000);</script>
</body>
</html>
''');
    request.response.close();
  }

  static Future<GoogleAuthResult?> _exchangeCode(
    String code,
    String redirectUri,
    String codeVerifier,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': codeVerifier,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final idToken = data['id_token'] as String?;
        final accessToken = data['access_token'] as String?;

        String? photoUrl;
        String? name;
        String? email;

        if (accessToken != null) {
          final userInfo = await _fetchUserInfo(accessToken);
          if (userInfo != null) {
            photoUrl = userInfo['picture'] as String?;
            name = userInfo['name'] as String?;
            email = userInfo['email'] as String?;
          }
        }

        if (idToken != null) {
          return GoogleAuthResult(
            idToken: idToken,
            photoUrl: photoUrl,
            name: name,
            email: email,
          );
        }
        return null;
      } else {
        debugPrint('[GoogleWindowsAuth] Token exchange failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[GoogleWindowsAuth] Token exchange error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[GoogleWindowsAuth] UserInfo fetch error: $e');
    }
    return null;
  }
}
