import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_connect_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_card.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.darkBg,
      ),
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomePage(),
            const ServersScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHomePage() {
    return Consumer<VpnProvider>(
      builder: (context, provider, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(provider),
              ),
              SliverToBoxAdapter(
                child: _buildConnectionSection(provider),
              ),
              SliverToBoxAdapter(
                child: _buildServerInfoCard(provider),
              ),
              SliverToBoxAdapter(
                child: _buildStatsSection(provider),
              ),
              SliverToBoxAdapter(
                child: _buildSniSection(provider),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(VpnProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'WaledNet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'اتصال آمن ومشفر 100%',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark.withOpacity(0.8),
                ),
              ),
            ],
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.darkBorder.withOpacity(0.5),
              ),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondaryDark,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection(VpnProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              provider.isConnected
                  ? '🟢 متصل وآمن'
                  : provider.isConnecting
                      ? '⏳ جاري الاتصال...'
                      : '⚪ غير متصل',
              key: ValueKey(provider.isConnected),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: provider.isConnected
                    ? AppColors.success
                    : provider.isConnecting
                        ? AppColors.warning
                        : AppColors.textSecondaryDark,
              ),
            ),
          ),
          const SizedBox(height: 30),
          AnimatedConnectButton(
            isConnected: provider.isConnected,
            isConnecting: provider.isConnecting,
            onTap: () => provider.toggleConnection(),
          ),
          const SizedBox(height: 30),
          if (provider.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'IP: ${provider.connectedIp ?? "محمي"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServerInfoCard(VpnProvider provider) {
    final server = provider.selectedServer;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () => setState(() => _currentIndex = 1),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.dns_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'السيرفر الحالي',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  server?.name ?? 'لم يتم الاختيار',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondaryDark.withOpacity(0.5),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(VpnProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.speed_rounded,
              label: 'السرعة',
              value: provider.isConnected ? '128 Mbps' : '--',
              gradient: AppColors.successGradient,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.timer_rounded,
              label: 'مدة الاتصال',
              value: provider.isConnected ? '02:34:12' : '--',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.data_usage_rounded,
              label: 'البيانات',
              value: provider.isConnected ? '1.2 GB' : '--',
              gradient: AppColors.dangerGradient,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSniSection(VpnProvider provider) {
    final profile = provider.selectedProfile;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SNI Profile',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.name ?? 'Direct / None',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
          if (profile?.sni.isNotEmpty ?? false)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                profile!.sni,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          top: BorderSide(
            color: AppColors.darkBorder.withOpacity(0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.dns_rounded,
                label: 'السيرفرات',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'الإعدادات',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondaryDark,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
