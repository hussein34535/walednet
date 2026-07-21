import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:WaledNet/services/admin_service.dart';
import 'package:WaledNet/services/api_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  String _prefKey(String key) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null ? '${uid}_$key' : 'guest_$key';
  }

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  String _priceLabel = '';
  String get priceLabel => _priceLabel;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_prefKey('is_premium')) ?? false;
    _priceLabel = prefs.getString(_prefKey('price_label')) ?? '';
    await _fetchPricing();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AdminService().ensureUserProfile(user);
      try {
        final cloudPremium = await AdminService().getUserPremiumStatus(user.uid);
        if (cloudPremium != _isPremium) {
          _isPremium = cloudPremium;
          await prefs.setBool(_prefKey('is_premium'), cloudPremium);
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchPricing() async {
    final pricing = await ApiService.fetchPricing();
    if (pricing.isNotEmpty) {
      final sub = pricing['subscription'] as Map<String, dynamic>?;
      final rawPrice = sub?['yearly_price']?.toString() ?? pricing['yearly_price']?.toString() ?? '';
      final currency = sub?['currency']?.toString() ?? pricing['currency']?.toString() ?? '';
      if (rawPrice.isNotEmpty) {
        _priceLabel = currency.isNotEmpty ? '$rawPrice $currency' : '$rawPrice ج.م';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey('price_label'), _priceLabel);
      }
    }
  }

  void setPremium(bool value) {
    _isPremium = value;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_prefKey('is_premium'), value);
    });
  }
}
