import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_page.dart';

class UpdateCheckPage extends StatefulWidget {
  const UpdateCheckPage({super.key});

  @override
  State<UpdateCheckPage> createState() => _UpdateCheckPageState();
}

class _UpdateCheckPageState extends State<UpdateCheckPage> {
  final String _updateUrl =
      'https://raw.githubusercontent.com/hussein34535/waledupdate/refs/heads/main/update.json';

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        _navigateToHome();
        return;
      }
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_updateUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'] as String;
        final updateUrl = data['update_url'] as String;

        if (_isUpdateRequired(currentVersion, latestVersion)) {
          if (mounted) {
            _showUpdateDialog(updateUrl);
          }
        } else {
          _navigateToHome();
        }
      } else {
        _navigateToHome();
      }
    } catch (e) {
      _navigateToHome();
    }
  }

  bool _isUpdateRequired(String currentVersion, String latestVersion) {
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final latestParts = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || currentParts[i] < latestParts[i]) {
        return true;
      }
      if (currentParts[i] > latestParts[i]) {
        return false;
      }
    }
    return false;
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MyHomePage()),
      );
    }
  }

  Future<void> _showUpdateDialog(String url) async {
    final Uri updateUri = Uri.parse(url);
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('تحتاج إلى تحديث'),
            content: const Text(
              'يتوفر إصدار جديد من التطبيق. الرجاء التحديث للمتابعة.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('تحديث الآن'),
                onPressed: () async {
                  if (!await launchUrl(
                    updateUri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not launch $url')),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
