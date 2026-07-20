import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/theme/app_colors.dart';
import 'package:WaledNet/widgets/glass_card.dart';

const _telegramUrl = 'https://t.me/D_S_D_Cbot';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
    final auth = Provider.of<AuthProvider>(context);
    final vpn = Provider.of<VpnProvider>(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
            child: const Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryDark,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        // Profile card
        SliverToBoxAdapter(
          child: GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: auth.isLoggedIn ? _buildLoggedInProfile(auth) : _buildGuestProfile(context, auth),
          ),
        ),
        // Subscription card
        SliverToBoxAdapter(
          child: _buildSubscriptionCard(context),
        ),
        // Connection settings
        SliverToBoxAdapter(
          child: _buildSettingsGroup(
            title: 'الاتصال',
            items: [
              _SettingItem(
                icon: Icons.wifi_rounded,
                title: 'الاتصال التلقائي',
                subtitle: 'اتصل تلقائياً عند فتح التطبيق',
                trailing: _buildSwitch(true),
              ),
              _SettingItem(
                icon: Icons.speed_rounded,
                title: 'السيرفر الحالي',
                subtitle: vpn.selectedServer?.name ?? 'غير محدد',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              _SettingItem(
                icon: Icons.fingerprint_rounded,
                title: 'SNI Profile',
                subtitle: vpn.selectedProfile?.displayName ?? 'غير محدد',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        // General settings
        SliverToBoxAdapter(
          child: _buildSettingsGroup(
            title: 'عام',
            items: [
              _SettingItem(
                icon: Icons.dark_mode_rounded,
                title: 'الوضع الداكن',
                subtitle: 'مفعّل دائماً',
                trailing: _buildSwitch(true),
              ),
              _SettingItem(
                icon: Icons.notifications_rounded,
                title: 'الإشعارات',
                subtitle: 'إشعارات حالة الاتصال',
                trailing: _buildSwitch(true),
              ),
              _SettingItem(
                icon: Icons.language_rounded,
                title: 'اللغة',
                subtitle: 'العربية',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        // About
        SliverToBoxAdapter(
          child: _buildSettingsGroup(
            title: 'حول',
            items: [
              _SettingItem(
                icon: Icons.info_outline_rounded,
                title: 'عن التطبيق',
                subtitle: 'WaledNet v1.0.0',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              _SettingItem(
                icon: Icons.privacy_tip_rounded,
                title: 'سياسة الخصوصية',
                subtitle: 'كيف نحمي بياناتك',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              _SettingItem(
                icon: Icons.star_rounded,
                title: 'قيّم التطبيق',
                subtitle: 'ساعدنا بتقييمك',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildLoggedInProfile(AuthProvider auth) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: auth.photoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(auth.photoUrl!, fit: BoxFit.cover),
                )
              : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.displayName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                auth.email,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => auth.signOut(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'تسجيل خروج',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestProfile(BuildContext context, AuthProvider auth) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'زائر',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'سجّل الدخول لمزامنة اشتراكك',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/login'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'تسجيل دخول',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0088CC), Color(0xFF005580)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0088CC).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.telegram, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'باقة سنوية - 50 ج.م',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'إزالة الإعلانات عبر تيليجرام',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openTelegram(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'تواصل',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0088CC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<_SettingItem> items,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.darkBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: items.map((item) {
                final isLast = item == items.last;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: AppColors.darkBorder.withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      item.trailing,
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(bool value) {
    return Container(
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: value ? AppColors.primaryGradient : null,
        color: value ? null : AppColors.darkCardLight,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
}
