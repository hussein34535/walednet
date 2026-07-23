import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/services/subscription_service.dart';
import '../widgets/server_bottom_sheet.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/connect_button.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/subscription_dialog.dart';
import '../widgets/server_flag_widget.dart';
import '../widgets/desktop_3d_stage.dart';
import '../widgets/mini_mascot_assistant.dart';
import '../services/windows_vpn_manager.dart';
import '../services/admin_service.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'account_screen.dart';
import 'admin_screen.dart';
import 'logs_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  AppLifecycleListener? _lifecycleListener;
  VpnProvider? _vpnProvider;
  bool _adsInitialized = false;

  void _vpnListener() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleStateChange,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _vpnProvider = Provider.of<VpnProvider>(context, listen: false);
        _vpnProvider!.addListener(_vpnListener);
        _vpnProvider!.initProvider();
      }
    });
  }

  void _handleAppLifecycleStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted && _vpnProvider != null) {
        _vpnProvider!.initProvider();
      }
    }
  }

  @override
  void dispose() {
    _vpnProvider?.removeListener(_vpnListener);
    _lifecycleListener?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.themeData;

    final isConnected = vpnProvider.vpnStatus == 'CONNECTED' ||
        vpnProvider.vpnStatus == 'CONNECTING';

    final isFullyConnected = vpnProvider.vpnStatus == 'CONNECTED';

    final bool isButtonLoading = vpnProvider.isLoading ||
        (vpnProvider.isAdLoading && !isConnected) ||
        (vpnProvider.vpnStatus == 'CONNECTING') ||
        vpnProvider.isVerifyingConnection;

    // Control pulse animation based on connection status (connected only)
    if (isFullyConnected) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(themeProvider),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopSplit = Platform.isWindows && constraints.maxWidth >= 750;

              Widget mainControls = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final height = innerConstraints.maxHeight;

                    final double topSpace = isFullyConnected ? 4 : 24;
                    final double middleSpace = isFullyConnected ? 16 : 36;
                    final double bottomSpace = isFullyConnected ? 12 : 24;

                    Widget content = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: topSpace,
                        ),
                        ConnectButton(
                          isConnected: isConnected,
                          isFullyConnected: isFullyConnected,
                          isButtonLoading: isButtonLoading,
                          isAdLoading: vpnProvider.isAdLoading,
                          buttonText: vpnProvider.buttonText,
                          pulseAnimation: _pulseAnimation,
                          onTap: vpnProvider.toggleVpn,
                          onExtend: vpnProvider.extendConnection,
                          isConnectionVerified: vpnProvider.isConnectionVerified,
                          connectionTime: vpnProvider.connectionTime,
                          isExtended: vpnProvider.isExtendedConnection,
                          isPremium: vpnProvider.isPremium,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: middleSpace,
                        ),
                        _buildConnectionDetails(vpnProvider, isDesktop: isDesktopSplit),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: bottomSpace,
                        ),
                      ],
                    );

                    final bool allowScroll = !Platform.isWindows && (isFullyConnected || height < 640);

                    return SingleChildScrollView(
                      physics: allowScroll
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: height,
                        ),
                        child: Container(
                          alignment: isFullyConnected ? Alignment.topCenter : Alignment.center,
                          child: content,
                        ),
                      ),
                    );
                  },
                ),
              );

              if (isDesktopSplit) {
                return Row(
                  children: [
                    // Left 48%: Interactive 3D Mascot Character Stage
                    const Expanded(
                      flex: 48,
                      child: Padding(
                        padding: EdgeInsets.only(left: 16, top: 12, bottom: 16, right: 8),
                        child: Desktop3dStage(),
                      ),
                    ),
                    // Right 52%: Controls & Status Panel
                    Expanded(
                      flex: 52,
                      child: mainControls,
                    ),
                  ],
                );
              }

              return Stack(
                children: [
                  mainControls,
                  DraggableMiniMascot(
                    status: vpnProvider.vpnStatus,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeProvider themeProvider) {
    final theme = themeProvider.themeData;
    final auth = context.watch<AuthProvider>();
    final isPremium = SubscriptionService().isPremium;

    final photoUrl = auth.photoUrl;
    final name = auth.displayName.trim();
    final initial = auth.isLoggedIn && name.isNotEmpty ? name.substring(0, 1).toUpperCase() : null;

    Widget avatarInner;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarInner = ClipOval(
        child: Image.network(
          photoUrl,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarFallback(theme, isPremium, initial),
        ),
      );
    } else {
      avatarInner = _buildAvatarFallback(theme, isPremium, initial);
    }

    Widget leadWidget = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isPremium
              ? const Color(0xFFF6C453)
              : (theme.iconTheme.color?.withValues(alpha: 0.25) ?? Colors.grey.withValues(alpha: 0.25)),
          width: isPremium ? 1.8 : 1.2,
        ),
      ),
      child: Center(child: avatarInner),
    );

    if (isPremium) {
      leadWidget = Badge(
        backgroundColor: const Color(0xFFF6C453),
        smallSize: 9,
        isLabelVisible: true,
        child: leadWidget,
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AccountScreen()),
          ),
          onLongPress: AdminService().isAdmin
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminScreen()),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: leadWidget,
          ),
        ),
      ),
      title: Text(
        'WaledNet',
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'اشتراك (منع الإعلانات)',
          icon: SvgPicture.asset(
            'assets/images/ad_block.svg',
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(
              Color(0xFFFF9500),
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const SubscriptionDialog(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.receipt_long_rounded),
          iconSize: 26,
          color: theme.iconTheme.color,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LogsPage()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAvatarFallback(ThemeData theme, bool isPremium, String? initial) {
    if (initial != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF007AFF),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    return Icon(
      Icons.person_rounded,
      color: isPremium ? const Color(0xFFF6C453) : theme.iconTheme.color,
      size: 22,
    );
  }

  Widget _buildConnectionDetails(VpnProvider vpnProvider, {bool isDesktop = false}) {
    final isConnected = vpnProvider.vpnStatus == 'CONNECTED' ||
        vpnProvider.vpnStatus == 'CONNECTING';
    final isFullyConnected = vpnProvider.vpnStatus == 'CONNECTED';

    return Column(
      children: [
        _buildSelectionMenus(vpnProvider, isDesktop: isDesktop),
        SizedBox(height: isConnected ? 12 : 20),
        if (isFullyConnected)
          ConnectionStatusCard(
            vpnStatus: vpnProvider.vpnStatus,
            isTestingSpeed: vpnProvider.isTestingSpeed,
            downloadSpeed: vpnProvider.speedTestResultMbps,
            uploadSpeed: vpnProvider.uploadSpeedTestResultMbps,
            liveDownlink: vpnProvider.downlink,
            liveUplink: vpnProvider.uplink,
            onSpeedTestPressed: vpnProvider.runSpeedTest,
          ),
      ],
    );
  }

  Widget _buildSelectionMenus(VpnProvider vpnProvider, {bool isDesktop = false}) {
    final server = vpnProvider.selectedServer;

    final serverTile = _buildSelectionTile(
      label: 'السيرفر المختار',
      title: server?.cleanName ?? 'Loading...',
      server: server,
      icon: Icons.dns_rounded,
      iconColor: const Color(0xFF007AFF),
      iconBgColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
      onTap: () => _showServerBottomSheet(vpnProvider),
      trailing: _buildSelectedServerPingWidget(vpnProvider),
      vpnProvider: vpnProvider,
      compact: isDesktop,
    );

    final sniTile = _buildSelectionTile(
      label: 'حزمة الشبكة (SNI)',
      title: vpnProvider.selectedProfile?.displayName ?? 'Loading...',
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF5856D6),
      iconBgColor: const Color(0xFF5856D6).withValues(alpha: 0.12),
      onTap: () => _showProfileBottomSheet(vpnProvider),
      vpnProvider: vpnProvider,
      compact: isDesktop,
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: serverTile),
          const SizedBox(width: 12),
          Expanded(child: sniTile),
        ],
      );
    }

    return Column(
      children: [
        serverTile,
        const SizedBox(height: 12),
        sniTile,
      ],
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String title,
    VpnServer? server,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    Widget? trailing,
    required VpnProvider vpnProvider,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDisabled = vpnProvider.isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? const Color(0xFF1C1C1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFE5E5EA),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                padding: server != null ? EdgeInsets.all(compact ? 6 : 7) : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(compact ? 13 : 14),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                ),
                child: server != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(compact ? 5 : 6),
                        child: ServerFlagWidget(
                          server: server,
                          width: compact ? 28 : 30,
                          height: compact ? 20 : 22,
                        ),
                      )
                    : Icon(
                        icon,
                        color: iconColor,
                        size: compact ? 20 : 22,
                      ),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 2 : 3),
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 14 : 15,
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: compact ? 4 : 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedServerPingWidget(VpnProvider vpnProvider) {
    if (vpnProvider.selectedServer == null) return const Text('...');
    final delay = vpnProvider.serverDelays[vpnProvider.selectedServer!.url];
    Color delayColor;
    String delayText;
    
    if (delay == null && vpnProvider.isPingingServers) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      );
    }

    if (delay == null) {
      delayText = '...';
      delayColor = Colors.grey;
    } else if (delay == -1 || delay == 0) {
      delayText = 'Offline';
      delayColor = const Color(0xFFFF3B30); // iOS Red
    } else {
      delayText = '${delay}ms';
      if (delay < 150) {
        delayColor = const Color(0xFF34C759); // iOS Green
      } else if (delay < 300) {
        delayColor = const Color(0xFFFF9500); // iOS Orange
      } else {
        delayColor = const Color(0xFFFF3B30); // iOS Red
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium breathing pulse dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: delayColor,
            boxShadow: [
              BoxShadow(
                color: delayColor.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: delayColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: delayColor.withOpacity(0.18),
              width: 1.0,
            ),
          ),
          child: Text(
            delayText,
            style: TextStyle(
              color: delayColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  void _showServerBottomSheet(VpnProvider vpnProvider) {
    // Refresh ping latency when opening the bottom sheet
    vpnProvider.pingAllServers();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return ServerBottomSheet(
          servers: vpnProvider.vpnServers,
          selectedServer: vpnProvider.selectedServer,
          serverDelays: vpnProvider.serverDelays,
          onServerSelected: (server) => vpnProvider.handleSelectionChange<VpnServer>(server),
        );
      },
    );
  }

  void _showProfileBottomSheet(VpnProvider vpnProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return ProfileBottomSheet(
          profiles: vpnProvider.sniProfiles,
          selectedProfile: vpnProvider.selectedProfile,
          onProfileSelected: (profile) => vpnProvider.handleSelectionChange<SniProfile>(profile),
        );
      },
    );
  }
}
