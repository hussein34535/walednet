import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:WaledNet/services/api_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  static const String yearlyId = 'subscription_yearly_50egp';
  static const List<String> productIds = [yearlyId];

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  String _priceLabel = '';
  String get priceLabel => _priceLabel;

  final StreamController<bool> _premiumController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStream => _premiumController.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    _priceLabel = prefs.getString('price_label') ?? '';

    await _fetchPricing();

    final available = await _inAppPurchase.isAvailable();
    if (available) {
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(_onPurchaseUpdate);
      await _loadProducts();
    } else {
      print('[Subscription] In-app purchases not available on this device');
    }
  }

  Future<void> _loadProducts() async {
    final available = await _inAppPurchase.queryProductDetails(productIds.toSet());
    if (available.notFoundIDs.isNotEmpty) {
      print('[Subscription] Products not found: ${available.notFoundIDs}');
    }
    _products = available.productDetails;
  }

  Future<void> _fetchPricing() async {
    final pricing = await ApiService.fetchPricing();
    if (pricing.isNotEmpty) {
      final rawPrice = pricing['yearly_price']?.toString() ?? '';
      final currency = pricing['currency']?.toString() ?? '';
      if (rawPrice.isNotEmpty) {
        _priceLabel = currency.isNotEmpty ? '$rawPrice $currency' : '$rawPrice ج.م';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('price_label', _priceLabel);
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _setPremium(true);
          _inAppPurchase.completePurchase(purchase);
        case PurchaseStatus.pending:
          print('[Subscription] Purchase pending: ${purchase.productID}');
        case PurchaseStatus.error:
          print('[Subscription] Purchase error: ${purchase.error}');
          _inAppPurchase.completePurchase(purchase);
        default:
          _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<bool> purchaseProduct(String productId) async {
    if (_products.isEmpty) return false;
    final detail = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => _products.first,
    );
    final param = PurchaseParam(productDetails: detail);
    return _inAppPurchase.buyConsumable(purchaseParam: param, autoConsume: false);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
    _premiumController.add(value);
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _premiumController.close();
  }
}
