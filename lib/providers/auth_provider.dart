import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:WaledNet/services/google_windows_auth.dart';

class AuthProvider with ChangeNotifier {
  FirebaseAuth? _auth;
  bool _googleInitialized = false;
  bool _windowsGoogleSupported = false;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _initialized;
  bool get isGoogleSupported => !Platform.isWindows || _windowsGoogleSupported;
  String get displayName =>
      _user?.displayName ?? _user?.email?.split('@').first ?? 'مستخدم';
  String get email => _user?.email ?? '';
  String? get photoUrl => _user?.photoURL;

  AuthProvider() {
    try {
      _auth = FirebaseAuth.instance;
      _initialized = true;
      _auth!.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      print('[Auth] Firebase init error: $e');
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId:
            '289358660533-cva5l6i7uesg99b87e5etj0cadaoioj5.apps.googleusercontent.com',
      );
      _googleInitialized = true;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    if (_auth == null) return false;
    _setLoading(true);
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = credential.user;
      await _saveLogin(true);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'حدث خطأ غير متوقع';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> registerWithEmail(
      String email, String password, String name) async {
    if (_auth == null) return false;
    _setLoading(true);
    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      _user = credential.user;
      await _saveLogin(true);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'حدث خطأ غير متوقع';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    if (_auth == null) return false;
    _setLoading(true);
    try {
      String? idToken;

      if (Platform.isWindows) {
        idToken = await GoogleWindowsAuth.signIn();
        if (idToken == null) {
          _setLoading(false);
          return false;
        }
      } else {
        await _ensureGoogleInitialized();
        final googleUser = await GoogleSignIn.instance.authenticate();
        idToken = googleUser.authentication.idToken;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth!.signInWithCredential(credential);
      _user = userCredential.user;
      await _saveLogin(true);
      _setLoading(false);
      return true;
    } catch (_) {
      _errorMessage = 'فشل تسجيل الدخول بجوجل';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth?.signOut();
    if (!Platform.isWindows) {
      await GoogleSignIn.instance.signOut();
    }
    _user = null;
    await _saveLogin(false);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _errorMessage = null;
    notifyListeners();
  }

  Future<void> _saveLogin(bool loggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', loggedIn);
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'too-many-requests':
        return 'محاولات كثيرة. حاول لاحقاً';
      case 'network-request-failed':
        return 'خطأ في الاتصال بالإنترنت';
      default:
        return 'حدث خطأ. حاول مرة أخرى';
    }
  }
}
