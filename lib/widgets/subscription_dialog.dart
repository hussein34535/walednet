import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:WaledNet/theme_provider.dart';

const _telegramUrl = 'https://t.me/D_S_D_Cbot';

class SubscriptionDialog extends StatelessWidget {
  const SubscriptionDialog({super.key});

  Future<void> _openTelegram(BuildContext context) async {
    final uri = Uri.parse(_telegramUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على تيليجرام')),
        );
      }
    }
  }

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
                  ? const Color(0xFF1C1F2E).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: themeProvider.isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, themeProvider, theme),
                const SizedBox(height: 8),
                _buildSubtitle(theme),
                const SizedBox(height: 28),
                _buildPlanCard(theme, themeProvider),
                const SizedBox(height: 24),
                _buildTelegramButton(context, theme),
                const SizedBox(height: 12),
                _buildSkipButton(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeProvider themeProvider, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
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
          icon: Icon(Icons.close_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 52),
      child: Text(
        'تواصل معنا على تيليجرام للحصول على اشتراكك وإزالة الإعلانات',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9500).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withValues(alpha: 0.15),
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
          const Text(
            '50 ج.م',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9500),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'لمدة سنة كاملة',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTelegramButton(BuildContext context, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _openTelegram(context),
        icon: const Icon(Icons.telegram, size: 22),
        label: const Text(
          'تواصل عبر تيليجرام',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0088CC),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context, ThemeData theme) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(
        'تخطي الآن',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 13,
        ),
      ),
    );
  }
}
