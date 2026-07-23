import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_usage.dart';

class UsageTrackerService {
  static final UsageTrackerService _instance = UsageTrackerService._();
  factory UsageTrackerService() => _instance;
  UsageTrackerService._();

  Timer? _syncTimer;
  int _lastUpload = 0;
  int _lastDownload = 0;
  static const String _storageKey = 'walednet_daily_usage_history';

  /// Starts the 30-second periodic sync timer during VPN session
  void startTracking() {
    _lastUpload = 0;
    _lastDownload = 0;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncUsage();
    });
  }

  /// Stops tracking and performs a final sync save
  void stopTracking() {
    _syncTimer?.cancel();
    _syncUsage();
  }

  /// Updates cumulative daily traffic deltas from sing-box / SSH tunnel live bytes
  Future<void> updateTraffic(int currentUpload, int currentDownload) async {
    if (currentUpload <= 0 && currentDownload <= 0) return;

    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final history = await _getLocalHistory();
    final existing = history[today];

    int deltaUp = 0;
    int deltaDown = 0;

    if (_lastUpload > 0 && currentUpload >= _lastUpload) {
      deltaUp = currentUpload - _lastUpload;
    } else if (_lastUpload == 0) {
      deltaUp = currentUpload;
    }

    if (_lastDownload > 0 && currentDownload >= _lastDownload) {
      deltaDown = currentDownload - _lastDownload;
    } else if (_lastDownload == 0) {
      deltaDown = currentDownload;
    }

    _lastUpload = currentUpload;
    _lastDownload = currentDownload;

    if (existing != null) {
      history[today] = existing.copyWith(
        uploadBytes: existing.uploadBytes + deltaUp,
        downloadBytes: existing.downloadBytes + deltaDown,
      );
    } else {
      history[today] = DailyUsage(
        date: today,
        uploadBytes: deltaUp,
        downloadBytes: deltaDown,
        sessionCount: 1,
      );
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(history.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// Increments today's session counter when VPN connects
  Future<void> incrementSession() async {
    final today = _todayKey();
    final history = await _getLocalHistory();
    final existing = history[today];

    if (existing != null) {
      history[today] = existing.copyWith(
        sessionCount: existing.sessionCount + 1,
      );
    } else {
      history[today] = DailyUsage(date: today, sessionCount: 1);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(history.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// Syncs current day usage payload to Firebase Firestore
  Future<void> _syncUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final history = await _getLocalHistory();
      final today = _todayKey();
      final todayUsage = history[today];
      if (todayUsage == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(today);

      await docRef.set(todayUsage.toJson(), SetOptions(merge: true));
    } catch (_) {}
  }

  /// Fetches daily usage history for the last N days (merges local + cloud)
  Future<List<DailyUsage>> getUsageHistory({int days = 30}) async {
    final Map<String, DailyUsage> combined = await _getLocalHistory();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .where('date', isGreaterThanOrEqualTo: _formatDate(cutoff))
            .orderBy('date', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final cloudItem = DailyUsage.fromJson(doc.data());
          if (!combined.containsKey(cloudItem.date) ||
              cloudItem.totalBytes > (combined[cloudItem.date]?.totalBytes ?? 0)) {
            combined[cloudItem.date] = cloudItem;
          }
        }
      } catch (_) {}
    }

    final list = combined.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Returns usage record for today
  Future<DailyUsage?> getTodayUsage() async {
    final history = await _getLocalHistory();
    return history[_todayKey()];
  }

  // ─── Helpers ───────────────────────────────────
  String _todayKey() => _formatDate(DateTime.now());

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<Map<String, DailyUsage>> _getLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map((k, v) => MapEntry(k, DailyUsage.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }
}
