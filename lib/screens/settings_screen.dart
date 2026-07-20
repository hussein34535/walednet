import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        SliverToBoxAdapter(
          child: GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مستخدم WaledNet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الخطة المجانية',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ترقية',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                title: 'بروتوكول الاتصال',
                subtitle: 'VLESS / VMess / SSH',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              _SettingItem(
                icon: Icons.fingerprint_rounded,
                title: 'SNI Profile',
                subtitle: 'إعدادات التشفير',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
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
                color: AppColors.darkBorder.withOpacity(0.5),
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
                              color: AppColors.darkBorder.withOpacity(0.3),
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
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
