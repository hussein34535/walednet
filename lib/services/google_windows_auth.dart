import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleWindowsAuth {
  static const String _clientId =
      '289358660533-cva5l6i7uesg99b87e5etj0cadaoioj5.apps.googleusercontent.com';
  static const String _tokenEndpoint =
      'https://oauth2.googleapis.com/token';
  static const String _authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const int _port = 8080;

  static Future<String?> signIn() async {
    final redirectUri = 'http://localhost:$_port';
    final state = _generateState();

    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid profile email',
      'state': state,
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
    final codeCompleter = Completer<String>();

    unawaited(
      _handleCallback(server, state, redirectUri, codeCompleter),
    );

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      server.close();
      return null;
    }

    try {
      final code = await codeCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('انتهت مهلة تسجيل الدخول'),
      );
      return await _exchangeCodeForIdToken(code, redirectUri);
    } finally {
      server.close();
    }
  }

  static String _generateState() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    return base64Url.encode(utf8.encode(random));
  }

  static Future<void> _handleCallback(
    HttpServer server,
    String expectedState,
    String redirectUri,
    Completer<String> codeCompleter,
  ) async {
    try {
      await for (final request in server) {
        if (request.uri.queryParameters.containsKey('code')) {
          final state = request.uri.queryParameters['state'];
          if (state != expectedState) {
            _respond(request, 400, 'State mismatch');
            codeCompleter.completeError(Exception('State mismatch'));
            return;
          }
          final code = request.uri.queryParameters['code']!;
          _respond(request, 200, 'تم تسجيل الدخول! يمكنك إغلاق هذه الصفحة.');
          codeCompleter.complete(code);
          return;
        } else if (request.uri.queryParameters.containsKey('error')) {
          _respond(request, 400, 'تم إلغاء تسجيل الدخول');
          codeCompleter.completeError(Exception('تم إلغاء تسجيل الدخول'));
          return;
        }
        _respond(request, 404, 'Not Found');
      }
    } catch (e) {
      if (!codeCompleter.isCompleted) {
        codeCompleter.completeError(e);
      }
    }
  }

  static void _respond(HttpRequest request, int status, String body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.text;
    request.response.write(body);
    request.response.close();
  }

  static Future<String?> _exchangeCodeForIdToken(
    String code,
    String redirectUri,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _clientId,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id_token'] as String?;
      } else {
        debugPrint('[GoogleWindowsAuth] Token exchange failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[GoogleWindowsAuth] Token exchange error: $e');
      return null;
    }
  }
}
