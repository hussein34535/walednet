import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/services/subscription_service.dart';
import 'package:WaledNet/theme_provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحساب'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildProfileHeader(context, theme, isDark),
          const SizedBox(height: 24),
          _buildSubscriptionCard(context, theme, isDark),
          const SizedBox(height: 24),
          _buildAccountActions(context, theme, isDark),
          const SizedBox(height: 24),
          _buildSettingsSection(context, theme, isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ThemeData theme, bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth * 0.18;

    return Consumer<SubscriptionService>(
      builder: (context, sub, _) {
        final isPremium = sub.isPremium;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A84FF), Color(0xFF5856D6)],
                      ),
                      borderRadius: BorderRadius.circular(avatarSize * 0.3),
                    ),
                    child: auth.photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(avatarSize * 0.3),
                            child: Image.network(auth.photoUrl!, fit: BoxFit.cover),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: avatarSize * 0.5,
                          ),
                  ),
                  if (isPremium)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                auth.displayName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                auth.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 12),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9500), Color(0xFFFF6B35)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Premium',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _openTelegram(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0088CC).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0088CC).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.telegram, size: 16, color: Color(0xFF0088CC)),
                        SizedBox(width: 6),
                        Text(
                          'اشتراك - إزالة الإعلانات',
                          style: TextStyle(
                            color: Color(0xFF0088CC),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!auth.isLoggedIn) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text('تسجيل دخول / إنشاء حساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1C1F2E), const Color(0xFF121622)]
              : [const Color(0xFFF0F9FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_rounded, size: 22, color: Color(0xFFFF9500)),
              const SizedBox(width: 10),
              Text(
                'الاشتراك',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<SubscriptionService>(
            builder: (context, sub, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sub.isPremium ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 18,
                        color: sub.isPremium ? const Color(0xFF34C759) : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sub.isPremium ? 'مشترك - بدون إعلانات' : 'نسخة مجانية - يوجد إعلانات',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (sub.isPremium) ...[
                    const SizedBox(height: 4),
                    Text(
                      'باقة سنوية - 50 ج.م',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _openTelegram(context),
              icon: const Icon(Icons.telegram, size: 18),
              label: const Text('تواصل عبر تيليجرام'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions(BuildContext context, ThemeData theme, bool isDark) {
    final auth = Provider.of<AuthProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'إدارة الحساب',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleSmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
          if (auth.isLoggedIn) ...[
            _buildActionTile(
              context,
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF0A84FF),
              title: 'تغيير كلمة المرور',
              onTap: () => _showChangePasswordDialog(context, auth, theme, isDark),
            ),
            _buildDivider(isDark),
            _buildActionTile(
              context,
              icon: Icons.delete_forever_rounded,
              iconColor: const Color(0xFFFF3B30),
              title: 'حذف الحساب',
              onTap: () => _showDeleteAccountDialog(context, auth, theme, isDark),
            ),
            _buildDivider(isDark),
          ],
          _buildActionTile(
            context,
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFFF9500),
            title: auth.isLoggedIn ? 'تسجيل خروج' : 'تسجيل دخول',
            onTap: () {
              if (auth.isLoggedIn) {
                auth.signOut();
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, ThemeData theme, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'عام',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleSmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
          _buildActionTile(
            context,
            icon: themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            iconColor: const Color(0xFFFF9500),
            title: themeProvider.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي',
            onTap: () {
              themeProvider.toggleTheme();
              Navigator.of(context).pop();
            },
          ),
          _buildDivider(isDark),
          _buildActionTile(
            context,
            icon: Icons.contact_support_outlined,
            iconColor: const Color(0xFF007AFF),
            title: 'تواصل معنا',
            onTap: () => _openTelegram(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withOpacity(0.04),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    AuthProvider auth,
    ThemeData theme,
    bool isDark,
  ) async {
    final oldPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1F2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('تغيير كلمة المرور'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.length < 6 ? '6 أحرف على الأقل' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != newPw.text ? 'غير متطابقة' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      HapticFeedback.mediumImpact();
      try {
        await auth.reauthenticate(oldPw.text);
        await auth.changePassword(newPw.text);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل تغيير كلمة المرور: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    AuthProvider auth,
    ThemeData theme,
    bool isDark,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1F2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('حذف الحساب'),
          content: const Text('هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      try {
        await auth.deleteAccount();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الحساب')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف الحساب: $e')),
          );
        }
      }
    }
  }

  Future<void> _openTelegram(BuildContext context) async {
    final uri = Uri.parse('https://t.me/D_S_D_Cbot');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على تيليجرام')),
      );
    }
  }
}
