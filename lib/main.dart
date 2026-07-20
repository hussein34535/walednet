import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/screens/update_check_page.dart';
import 'package:WaledNet/screens/login_screen.dart';
import 'package:WaledNet/screens/home_page.dart';
import 'package:WaledNet/services/subscription_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (Platform.isAndroid) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('onMessageOpenedApp: ${message.data}');
    });
  }

  try {
    await SubscriptionService().init();
  } catch (e) {
    print('[Main] SubscriptionService init failed (expected without Google Play): $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => VpnProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: const VpnApp(),
    ),
  );
}

class VpnApp extends StatelessWidget {
  const VpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaledNet VPN',
      theme: Provider.of<ThemeProvider>(context).themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const UpdateCheckPage(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MyHomePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
