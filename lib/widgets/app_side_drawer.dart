import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../services/subscription_service.dart';
import '../services/admin_service.dart';
import '../theme_provider.dart';
import '../screens/usage_stats_screen.dart';
import '../screens/logs_page.dart';
import '../screens/admin_screen.dart';
import 'referral_dialog.dart';
import 'subscription_dialog.dart';

class AppSideDrawer extends StatefulWidget {
  const AppSideDrawer({super.key});

  @override
  State<AppSideDrawer> createState() => _AppSideDrawerState();
}

class _AppSideDrawerState extends State<AppSideDrawer> {
  String _version = '2.0.0';

  static const _brandA = Color(0xFF4834D4);
  static const _brandB = Color(0xFF6C5CE7);
  static const _gold = Color(0xFFF6C453);
  static const _goldDeep = Color(0xFFE8A33D);
  static const _goldInk = Color(0xFF4A2E00);
  static const _telegram = Color(0xFF0088CC);
  static const _danger = Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _openTelegram() async {
    const url = 'https://t.me/Waled_net';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;
    final isPremium = SubscriptionService().isPremium;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1018).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.96),
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // User Profile Header (ChatGPT / Gemini Style)
                  _buildUserHeader(context, auth, isPremium, isDark),

                  const SizedBox(height: 12),

                  // Main Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Premium Banner (If not premium)
                        if (!isPremium) _buildUpgradeCard(context, isDark),
                        if (!isPremium) const SizedBox(height: 16),

                        // Section 1: Services & Stats
                        _sectionTitle('الخدمات والإحصائيات'),
                        _drawerTile(
                          icon: Icons.bar_chart_rounded,
                          iconColor: const Color(0xFF007AFF),
                          title: 'إحصائيات استخدام البيانات',
                          subtitle: 'متابعة الاستهلاك اليومي',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const UsageStatsScreen()),
                            );
                          },
                        ),
                        _drawerTile(
                          icon: Icons.card_giftcard_rounded,
                          iconColor: const Color(0xFF34C759),
                          title: 'نظام الإحالة والجوائز',
                          subtitle: 'شهر بريميوم مجاناً 🎁',
                          onTap: () {
                            Navigator.pop(context);
                            ReferralDialog.show(context);
                          },
                        ),
                        _drawerTile(
                          icon: Icons.receipt_long_rounded,
                          iconColor: const Color(0xFFFF9500),
                          title: 'سجلات التشغيل والاتصال',
                          subtitle: 'عرض السجلات التفصيلية',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LogsPage()),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        _sectionTitle('التفضيلات والمظهر'),

                        // Section 2: Dark Mode Toggle
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                color: const Color(0xFFFF9500),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              isDark ? 'الوضع الليلي' : 'الوضع النهاري',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            value: isDark,
                            onChanged: (_) => themeProvider.toggleTheme(),
                          ),
                        ),

                        if (auth.isLoggedIn)
                          _drawerTile(
                            icon: Icons.lock_outline_rounded,
                            iconColor: const Color(0xFF5856D6),
                            title: 'تغيير كلمة المرور',
                            onTap: () => _showChangePasswordDialog(context, auth),
                          ),

                        if (AdminService().isAdmin)
                          _drawerTile(
                            icon: Icons.admin_panel_settings_rounded,
                            iconColor: const Color(0xFFFF2D55),
                            title: 'لوحة التحكم (Admin)',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminScreen()),
                              );
                            },
                          ),

                        const SizedBox(height: 16),
                        _sectionTitle('الدعم والحساب'),

                        _drawerTile(
                          icon: Icons.support_agent_rounded,
                          iconColor: _telegram,
                          title: 'الدعم المباشر عبر تيليجرام',
                          onTap: _openTelegram,
                        ),

                        _drawerTile(
                          icon: auth.isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                          iconColor: auth.isLoggedIn ? _danger : _brandB,
                          title: auth.isLoggedIn ? 'تسجيل الخروج' : 'تسجيل الدخول',
                          titleColor: auth.isLoggedIn ? _danger : null,
                          onTap: () {
                            Navigator.pop(context);
                            if (auth.isLoggedIn) {
                              auth.signOut();
                            } else {
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Bottom Drawer Footer
                  _buildFooter(theme, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(
    BuildContext context,
    AuthProvider auth,
    bool isPremium,
    bool isDark,
  ) {
    final name = auth.displayName.trim();
    final initial = auth.isLoggedIn && name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar Stack
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isPremium
                      ? const LinearGradient(colors: [_gold, _goldDeep])
                      : const LinearGradient(colors: [_brandA, _brandB]),
                ),
                child: ClipOval(
                  child: auth.photoUrl != null
                      ? Image.network(auth.photoUrl!, fit: BoxFit.cover)
                      : Container(
                          color: _brandA,
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (isPremium)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 12,
                      color: _goldInk,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Name and Email Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.isLoggedIn ? auth.displayName : 'مستخدم زائر',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  auth.isLoggedIn ? auth.email : 'WaledNet Guest',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Badge Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPremium
                        ? _gold.withValues(alpha: 0.2)
                        : _brandA.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isPremium ? 'اشتراك بريميوم 👑' : 'الخطة المجانية ⚡',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isPremium ? _goldDeep : _brandB,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandA, _brandB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brandB.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: _gold, size: 20),
              SizedBox(width: 8),
              Text(
                'الترقية إلى بريميوم',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'اتصال غير محدود وبدون إعلانات',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const SubscriptionDialog(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _goldInk,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('اشترك الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: titleColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_left_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Text(
        'WaledNet VPN • الإصدار $_version',
        style: TextStyle(
          fontSize: 11.5,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final newPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تغيير كلمة المرور'),
        content: TextField(
          controller: newPassCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'كلمة المرور الجديدة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassCtrl.text.length >= 6) {
                await auth.changePassword(newPassCtrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
