import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:WaledNet/models/user_model.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  static const _collection = 'users';
  static const _adminsCollection = 'admins';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;
  bool _adminChecked = false;
  bool get adminChecked => _adminChecked;

  Future<void> checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      _isAdmin = false;
      _adminChecked = true;
      return;
    }
    final email = user!.email!.toLowerCase().trim();

    final adminEmails = ['hussona4635@gmail.com'];

    if (adminEmails.contains(email)) {
      _isAdmin = true;
      _adminChecked = true;
      return;
    }

    try {
      final doc = await _db.collection(_adminsCollection).doc(user.uid).get();
      if (doc.exists && doc.data()?['isAdmin'] == true) {
        _isAdmin = true;
      }
    } catch (_) {}

    if (!_isAdmin) {
      try {
        final qs = await _db
            .collection(_adminsCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty && qs.docs.first.data()['isAdmin'] == true) {
          _isAdmin = true;
        }
      } catch (_) {}
    }

    _adminChecked = true;
  }

  Future<void> ensureUserProfile(User user) async {
    if (user.email == null) return;
    try {
      final doc = await _db.collection(_collection).doc(user.uid).get();
      if (!doc.exists) {
        final now = DateTime.now();
        await _db.collection(_collection).doc(user.uid).set({
          'email': user.email!.toLowerCase().trim(),
          'displayName': user.displayName ?? '',
          'photoUrl': user.photoURL,
          'isPremium': false,
          'isBanned': false,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    } catch (e) {
      print('[AdminService] ensureUserProfile error: $e');
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(uid, doc.data()!);
    } catch (e) {
      print('[AdminService] getUserProfile error: $e');
      return null;
    }
  }

  Future<bool> getUserPremiumStatus(String uid) async {
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (!doc.exists) return false;
      return doc.data()?['isPremium'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final total = await _db.collection(_collection).count().get();
      final premium = await _db
          .collection(_collection)
          .where('isPremium', isEqualTo: true)
          .count()
          .get();
      final banned = await _db
          .collection(_collection)
          .where('isBanned', isEqualTo: true)
          .count()
          .get();
      return {
        'total': total.count,
        'premium': premium.count,
        'banned': banned.count,
      };
    } catch (_) {
      return {'total': 0, 'premium': 0, 'banned': 0};
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    try {
      final byEmail = await _db
          .collection(_collection)
          .where('email', isGreaterThanOrEqualTo: q)
          .where('email', isLessThanOrEqualTo: '$q\uf8ff')
          .orderBy('email')
          .limit(50)
          .get();

      final Set<String> found = byEmail.docs.map((d) => d.id).toSet();
      final results = <UserModel>[];
      for (final doc in byEmail.docs) {
        results.add(UserModel.fromMap(doc.id, doc.data()));
      }

      final byName = await _db
          .collection(_collection)
          .where('displayName', isGreaterThanOrEqualTo: q)
          .where('displayName', isLessThanOrEqualTo: '$q\uf8ff')
          .orderBy('displayName')
          .limit(50)
          .get();

      for (final doc in byName.docs) {
        if (!found.contains(doc.id)) {
          results.add(UserModel.fromMap(doc.id, doc.data()));
        }
      }

      return results;
    } catch (e) {
      print('[AdminService] searchUsers error: $e');
      return [];
    }
  }

  Future<List<UserModel>> getRecentUsers({int limit = 20}) async {
    try {
      final qs = await _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return qs.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> togglePremium(String uid, bool value, String adminEmail) async {
    try {
      final update = <String, dynamic>{
        'isPremium': value,
        'updatedAt': DateTime.now(),
      };
      if (value) {
        update['premiumActivatedAt'] = DateTime.now();
        update['premiumActivatedBy'] = adminEmail;
      }
      await _db.collection(_collection).doc(uid).update(update);
      return true;
    } catch (e) {
      print('[AdminService] togglePremium error: $e');
      return false;
    }
  }

  Future<bool> toggleBan(String uid, bool value) async {
    try {
      await _db.collection(_collection).doc(uid).update({
        'isBanned': value,
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('[AdminService] toggleBan error: $e');
      return false;
    }
  }
}
