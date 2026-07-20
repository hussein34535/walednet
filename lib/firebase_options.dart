import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

FirebaseOptions get desktopFirebaseOptions => FirebaseOptions(
      apiKey: 'AIzaSyDRNcrIOz8mUHRqQk4d_JUualOIIBc9w4E',
      appId: '1:289358660533:web:8cff3ff3a9759e6f990ffc',
      messagingSenderId: '289358660533',
      projectId: 'waledpro-f',
      authDomain: 'waledpro-f.firebaseapp.com',
      storageBucket: 'waledpro-f.firebasestorage.app',
    );

bool get isDesktopPlatform =>
    !Platform.isAndroid && !Platform.isIOS && !kIsWeb;
