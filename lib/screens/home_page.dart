import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/data/servers.dart';
import '../widgets/server_bottom_sheet.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/connect_button.dart';
import '../widgets/connection_status_card.dart';
import '../services/windows_vpn_manager.dart';

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

  final Uri _telegramUrl = Uri.parse('https://t.me/D_S_D_C1');
  final Uri _subscriptionUrl = Uri.parse('https://t.me/D_S_D_Cbot');
  final Uri _developerUrl = Uri.parse('https://t.me/he_s_en');

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _lifecycleListener = AppLifecycleListener(
        onExitRequested: () async {
          await WindowsVpnManager.stopVpn();
          return AppExitResponse.exit;
        },
      );
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _launchUrl(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch ${url.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching URL: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
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
        vpnProvider.vpnStatus == 'CONNECTING' ||
        vpnProvider.status?.state == 'CONNECTED' ||
        vpnProvider.status?.state == 'CONNECTING' ||
        vpnProvider.isVerifyingConnection ||
        vpnProvider.isConnectingUserTrigger;

    final bool isButtonLoading = vpnProvider.isLoading ||
        (vpnProvider.isAdLoading && !isConnected) ||
        (vpnProvider.status?.state == 'CONNECTING') ||
        vpnProvider.isVerifyingConnection;

    // Control pulse animation based on status
    if (isConnected || isButtonLoading) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(themeProvider),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          gradient: themeProvider.isDarkMode
              ? const RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    Color(0xFF0C1030), // Extremely subtle dark blue tint at the center
                    Color(0xFF000000), // True black background
                  ],
                )
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;

                final double topSpace = isConnected ? 4 : 24;
                final double middleSpace = isConnected ? 16 : 36;
                final double bottomSpace = isConnected ? 12 : 24;

                Widget content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: topSpace),
                    ConnectButton(
                      isConnected: isConnected,
                      isButtonLoading: isButtonLoading,
                      isAdLoading: vpnProvider.isAdLoading,
                      buttonText: vpnProvider.buttonText,
                      pulseAnimation: _pulseAnimation,
                      onTap: vpnProvider.toggleVpn,
                      isConnectionVerified: vpnProvider.isConnectionVerified,
                      connectionTime: vpnProvider.connectionTime,
                    ),
                    SizedBox(height: middleSpace),
                    _buildConnectionDetails(vpnProvider),
                    SizedBox(height: bottomSpace),
                  ],
                );

                final bool allowScroll = isConnected || height < 640;

                return SingleChildScrollView(
                  physics: allowScroll
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: height,
                    ),
                    child: Container(
                      alignment: isConnected ? Alignment.topCenter : Alignment.center,
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeProvider themeProvider) {
    final theme = themeProvider.themeData;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'contact_us') {
            _launchUrl(_telegramUrl);
          } else if (value == 'subscribe') {
            _launchUrl(_subscriptionUrl);
          } else if (value == 'developer') {
            _launchUrl(_developerUrl);
          }
        },
        icon: Icon(Icons.menu_rounded, color: theme.iconTheme.color, size: 28),
        color: theme.cardTheme.color,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'contact_us',
            child: Row(
              children: [
                const Icon(
                  Icons.contact_support_outlined,
                  color: Color(0xFF007AFF), // iOS Blue
                ),
                const SizedBox(width: 12),
                Text(
                  'تواصل معنا',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'subscribe',
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFFF9500), // iOS Orange
                ),
                const SizedBox(width: 12),
                Text(
                  'اشتراك (بدون إعلانات)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'developer',
            child: Row(
              children: [
                const Icon(
                  Icons.code_rounded,
                  color: Color(0xFF5856D6), // iOS Purple
                ),
                const SizedBox(width: 12),
                Text(
                  r'المطور :7𝖊$𝖊𝒏',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          icon: const Icon(Icons.telegram, color: Color(0xFF007AFF)),
          iconSize: 28,
          onPressed: () => _launchUrl(_telegramUrl),
        ),
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
          iconSize: 26,
          color: theme.iconTheme.color,
          onPressed: () => themeProvider.toggleTheme(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildConnectionDetails(VpnProvider vpnProvider) {
    final isConnected = vpnProvider.vpnStatus == 'CONNECTED' ||
        vpnProvider.vpnStatus == 'CONNECTING' ||
        vpnProvider.status?.state == 'CONNECTED' ||
        vpnProvider.status?.state == 'CONNECTING';

    return Column(
      children: [
        _buildSelectionMenus(vpnProvider),
        SizedBox(height: isConnected ? 12 : 20),
        ConnectionStatusCard(
          vpnStatus: vpnProvider.vpnStatus,
          isTestingSpeed: vpnProvider.isTestingSpeed,
          downloadSpeed: vpnProvider.speedTestResultMbps,
          uploadSpeed: vpnProvider.uploadSpeedTestResultMbps,
          onSpeedTestPressed: vpnProvider.runSpeedTest,
        ),
      ],
    );
  }

  Widget _buildSelectionMenus(VpnProvider vpnProvider) {
    return Column(
      children: [
        _buildSelectionTile(
          label: 'السيرفر المختار',
          title: vpnProvider.selectedServer?.name ?? 'Loading...',
          icon: Icons.dns_rounded,
          iconColor: const Color(0xFF007AFF), // iOS Blue
          iconBgColor: const Color(0xFF007AFF).withOpacity(0.12),
          onTap: () => _showServerBottomSheet(vpnProvider),
          trailing: _buildSelectedServerPingWidget(vpnProvider),
          vpnProvider: vpnProvider,
        ),
        const SizedBox(height: 12),
        _buildSelectionTile(
          label: 'حزمة الشبكة (SNI)',
          title: vpnProvider.selectedProfile?.name ?? 'Loading...',
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF5856D6), // iOS Purple
          iconBgColor: const Color(0xFF5856D6).withOpacity(0.12),
          onTap: () => _showProfileBottomSheet(vpnProvider),
          vpnProvider: vpnProvider,
        ),
      ],
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    Widget? trailing,
    required VpnProvider vpnProvider,
  }) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDisabled = vpnProvider.isLoading;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.03),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.1 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ] else ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedServerPingWidget(VpnProvider vpnProvider) {
    if (vpnProvider.selectedServer == null) return const Text('...');
    final delay = vpnProvider.serverDelays[vpnProvider.selectedServer!.url];
    Color delayColor;
    String delayText;
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

    if (vpnProvider.isPingingServers) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: delayColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        delayText,
        style: TextStyle(
          color: delayColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showServerBottomSheet(VpnProvider vpnProvider) {
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
