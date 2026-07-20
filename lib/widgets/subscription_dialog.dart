import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/services/subscription_service.dart';

class SubscriptionDialog extends StatefulWidget {
  const SubscriptionDialog({super.key});

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  final _subService = SubscriptionService();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.themeData;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? const Color(0xFF1C1F2E).withOpacity(0.95)
                  : Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(themeProvider, theme),
                const SizedBox(height: 8),
                _buildSubtitle(theme),
                const SizedBox(height: 28),
                _buildPlanCard(theme, themeProvider),
                const SizedBox(height: 24),
                _buildSubscribeButton(theme, themeProvider),
                const SizedBox(height: 12),
                _buildRestoreButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.block_rounded, color: Color(0xFFFF9500), size: 28),
        ),
        const SizedBox(width: 14),
        Text(
          'إزالة الإعلانات',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 52),
      child: Text(
        'استمتع بتجربة خالية من الإعلانات باقة سنوية واحدة',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildPlanCard(ThemeData theme, ThemeProvider themeProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9500).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'الأفضل',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF9500),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'باقة سنوية',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subService.priceLabel.isNotEmpty ? _subService.priceLabel : '50 ج.م',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF9500),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'لمدة سنة كاملة',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          _buildFeature(theme, Icons.check_circle_rounded, 'تصفح بدون إعلانات'),
          const SizedBox(height: 6),
          _buildFeature(theme, Icons.check_circle_rounded, 'اتصال أسرع وأكثر استقراراً'),
          const SizedBox(height: 6),
          _buildFeature(theme, Icons.check_circle_rounded, 'دعم التطبيق والمطور'),
        ],
      ),
    );
  }

  Widget _buildFeature(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFF9500)),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        )),
      ],
    );
  }

  Widget _buildSubscribeButton(ThemeData theme, ThemeProvider themeProvider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => _purchase(SubscriptionService.yearlyId),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9500),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
          child: Text(
            'اشترك الآن - ${_subService.priceLabel.isNotEmpty ? _subService.priceLabel : "50 ج.م"}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(ThemeData theme) {
    return TextButton(
      onPressed: () => _subService.restorePurchases(),
      child: Text(
        'استعادة المشتريات',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _purchase(String productId) async {
    final success = await _subService.purchaseProduct(productId);
    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاشتراك بنجاح! شكراً لك.')),
      );
    }
  }
}
