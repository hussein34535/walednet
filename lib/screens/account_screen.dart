import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/services/subscription_service.dart';
import 'package:WaledNet/theme/app_colors.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/widgets/referral_dialog.dart';
import 'package:WaledNet/screens/usage_stats_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  String _version = '';

  static const _brandA = Color(0xFF4834D4);
  static const _brandB = Color(0xFF6C5CE7);
  static const _gold = Color(0xFFF6C453);
  static const _goldDeep = Color(0xFFE8A33D);
  static const _goldInk = Color(0xFF4A2E00);
  static const _telegram = Color(0xFF0088CC);
  static const _danger = Color(0xFFFF3B30);
  static const _success = Color(0xFF34C759);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward();
      }
    });
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    final start = (index * 0.09).clamp(0.0, 0.45);
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final ink = isDark ? Colors.white : AppColors.textPrimaryLight;
    final muted =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                _buildTopBar(context, card, border, ink),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 12),
                      _reveal(0, _buildProfileHero(context, isDark, card, border, ink, muted)),
                      const SizedBox(height: 28),
                      _reveal(1, _buildSubscriptionCard(context, isDark, card, border, ink, muted)),
                      const SizedBox(height: 28),
                      _reveal(2, _buildAccountActions(context, isDark, card, border, ink, muted)),
                      const SizedBox(height: 24),
                      _reveal(3, _buildSettingsSection(context, isDark, card, border, ink, muted)),
                      const SizedBox(height: 32),
                      _reveal(4, _buildFooter(muted)),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color card, Color border, Color ink) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Material(
            color: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back_rounded, size: 20, color: ink),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'الحساب',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
          ),
        ],
      ),
    );
  }

  // ─── Profile hero ───────────────────────────────────────────────

  Widget _buildProfileHero(
    BuildContext context,
    bool isDark,
    Color card,
    Color border,
    Color ink,
    Color muted,
  ) {
    final auth = context.watch<AuthProvider>();
    final isPremium = SubscriptionService().isPremium;

    return Column(
      children: [
        _buildAvatar(auth, isPremium, isDark),
        const SizedBox(height: 16),
        Text(
          auth.isLoggedIn ? auth.displayName : 'زائر',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink),
        ),
        if (auth.email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            auth.email,
            style: TextStyle(fontSize: 13.5, color: muted),
          ),
        ],
        const SizedBox(height: 14),
        _buildMembershipChip(isPremium, card, border, muted),
        if (!auth.isLoggedIn) ...[
          const SizedBox(height: 20),
          _gradientButton(
            label: 'تسجيل دخول / إنشاء حساب',
            icon: Icons.login_rounded,
            onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(AuthProvider auth, bool isPremium, bool isDark) {
    final name = auth.displayName.trim();
    final initial = auth.isLoggedIn && name.isNotEmpty ? name.substring(0, 1) : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPremium
                ? const LinearGradient(
                    colors: [_gold, _goldDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: isPremium
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: ClipOval(
              child: auth.photoUrl != null
                  ? Image.network(
                      auth.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(initial),
                    )
                  : _avatarFallback(initial),
            ),
          ),
        ),
        if (isPremium)
          Positioned(
            bottom: -2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_gold, _goldDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarFallback(String? initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandA, _brandB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: initial != null
            ? Text(
                initial,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.person_rounded, color: Colors.white, size: 44),
      ),
    );
  }

  Widget _buildMembershipChip(bool isPremium, Color card, Color border, Color muted) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gold, _goldDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 14, color: _goldInk),
            SizedBox(width: 6),
            Text(
              'عضوية بريميوم',
              style: TextStyle(
                color: _goldInk,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        'الخطة المجانية',
        style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
  }

  // ─── Subscription ───────────────────────────────────────────────

  Widget _buildSubscriptionCard(
    BuildContext context,
    bool isDark,
    Color card,
    Color border,
    Color ink,
    Color muted,
  ) {
    final sub = SubscriptionService();
    final price = sub.priceLabel.isNotEmpty ? sub.priceLabel : '50 ج.م';
    return sub.isPremium
        ? _buildPremiumCard(isDark, price)
        : _buildUpgradeCard(context, isDark, card, border, ink, muted, price);
  }

  Widget _buildPremiumCard(bool isDark, String price) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandA, _brandB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _brandB.withValues(alpha: isDark ? 0.35 : 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -46,
              right: -36,
              child: _glowCircle(150, Colors.white, 0.07),
            ),
            Positioned(
              bottom: -56,
              left: -30,
              child: _glowCircle(170, AppColors.accent, 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: _gold,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'مفعلة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'عضوية بريميوم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تجربة كاملة بدون إعلانات',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'باقة سنوية • $price',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildUpgradeCard(
    BuildContext context,
    bool isDark,
    Color card,
    Color border,
    Color ink,
    Color muted,
    String price,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brandA, _brandB],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الترقية إلى بريميوم',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'افتح التجربة الكاملة',
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _benefitRow('بدون أي إعلانات مزعجة', ink),
          const SizedBox(height: 10),
          _benefitRow('دعم مباشر وسريع عبر تيليجرام', ink),
          const SizedBox(height: 10),
          _benefitRow('باقة سنوية — $price فقط', ink),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _openTelegram(context),
              icon: const Icon(Icons.telegram, size: 20),
              label: const Text(
                'اشترك عبر تيليجرام',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _telegram,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(String text, Color ink) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: _success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: ink.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Action groups ──────────────────────────────────────────────

  Widget _buildAccountActions(
    BuildContext context,
    bool isDark,
    Color card,
    Color border,
    Color ink,
    Color muted,
  ) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('إدارة الحساب', muted),
        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              _buildActionTile(
                context,
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF007AFF),
                title: 'إحصائيات استخدام البيانات 📊',
                ink: ink,
                muted: muted,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsageStatsScreen()),
                ),
              ),
              _buildDivider(isDark),
              _buildActionTile(
                context,
                icon: Icons.card_giftcard_rounded,
                iconColor: const Color(0xFF34C759),
                title: 'نظام الإحالة كسب مكافآت',
                ink: ink,
                muted: muted,
                onTap: () => ReferralDialog.show(context),
              ),
              _buildDivider(isDark),
              if (auth.isLoggedIn) ...[
                _buildActionTile(
                  context,
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF0A84FF),
                  title: 'تغيير كلمة المرور',
                  ink: ink,
                  muted: muted,
                  onTap: () => _showChangePasswordDialog(context, auth, isDark),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  context,
                  icon: Icons.delete_forever_rounded,
                  iconColor: _danger,
                  title: 'حذف الحساب',
                  titleColor: _danger,
                  ink: ink,
                  muted: muted,
                  onTap: () => _showDeleteAccountDialog(context, auth, isDark),
                ),
                _buildDivider(isDark),
              ],
              _buildActionTile(
                context,
                icon: auth.isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                iconColor: auth.isLoggedIn ? const Color(0xFFFF9500) : const Color(0xFF0A84FF),
                title: auth.isLoggedIn ? 'تسجيل خروج' : 'تسجيل دخول',
                ink: ink,
                muted: muted,
                onTap: () {
                  if (auth.isLoggedIn) {
                    auth.signOut();
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    bool isDark,
    Color card,
    Color border,
    Color ink,
    Color muted,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('عام', muted),
        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              _buildActionTile(
                context,
                icon: themeProvider.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                iconColor: const Color(0xFFFF9500),
                title: themeProvider.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي',
                ink: ink,
                muted: muted,
                onTap: () {
                  themeProvider.toggleTheme();
                  Navigator.of(context).pop();
                },
              ),
              _buildDivider(isDark),
              _buildActionTile(
                context,
                icon: Icons.contact_support_outlined,
                iconColor: _telegram,
                title: 'تواصل معنا',
                ink: ink,
                muted: muted,
                onTap: () => _openTelegram(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4, left: 4),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color ink,
    required Color muted,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor ?? ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: muted.withValues(alpha: 0.4),
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
      indent: 70,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _brandB.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(Color muted) {
    return Center(
      child: Text(
        _version.isEmpty ? 'WaledNet' : 'WaledNet • v$_version',
        style: TextStyle(fontSize: 12, color: muted.withValues(alpha: 0.6)),
      ),
    );
  }

  // ─── Dialogs ────────────────────────────────────────────────────

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    AuthProvider auth,
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
              style: ElevatedButton.styleFrom(backgroundColor: _danger),
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
