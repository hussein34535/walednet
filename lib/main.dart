import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/screens/home_screen.dart';
import 'package:WaledNet/services/subscription_service.dart';
import 'package:WaledNet/theme/app_theme.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await SubscriptionService().init();
  } catch (e) {
    debugPrint('[Main] SubscriptionService init failed: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => VpnProvider(),
      child: const WaledNetApp(),
    ),
  );
}

class WaledNetApp extends StatelessWidget {
  const WaledNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaledNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
