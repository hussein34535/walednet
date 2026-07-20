import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/services/subscription_service.dart';
import '../widgets/server_bottom_sheet.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/connect_button.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/subscription_dialog.dart';
import '../services/windows_vpn_manager.dart';
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
  String? _lastStatus;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _vpnProvider = Provider.of<VpnProvider>(context, listen: false);
        _vpnProvider!.addListener(_vpnListener);
        _lastStatus = _vpnProvider!.vpnStatus;
        _vpnProvider!.initProvider();
      }
    });
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
          gradient: themeProvider.isDarkMode
              ? const RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.3,
                  colors: [
                    Color(0xFF0F172A), // Deep Slate Midnight Accent
                    Color(0xFF07090E), // Obsidian Black Base
                  ],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFEDF2F7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
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
                      isConnectionVerified: vpnProvider.isConnectionVerified,
                      connectionTime: vpnProvider.connectionTime,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: middleSpace,
                    ),
                    _buildConnectionDetails(vpnProvider),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: bottomSpace,
                    ),
                  ],
                );

                final bool allowScroll = !Platform.isWindows && (isConnected || height < 640);

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
          } else if (value == 'theme') {
            themeProvider.toggleTheme();
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
          PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'theme',
            child: Row(
              children: [
                Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: const Color(0xFFFF9500),
                ),
                const SizedBox(width: 12),
                Text(
                  themeProvider.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي',
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

  Widget _buildConnectionDetails(VpnProvider vpnProvider) {
    final isConnected = vpnProvider.vpnStatus == 'CONNECTED' ||
        vpnProvider.vpnStatus == 'CONNECTING';

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.09)
                    : Colors.black.withOpacity(0.05),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.25 : 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                      width: 1.0,
                    ),
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
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.1,
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
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.25),
                    size: 26,
                  ),
                ],
              ],
            ),
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

  void _vpnListener() {
    if (!mounted) return;
    final currentStatus = _vpnProvider!.vpnStatus;
    if (_lastStatus == 'CONNECTING' && currentStatus == 'CONNECTED') {
      _showRewardVideoDialog();
    }
    _lastStatus = currentStatus;
  }

  void _showRewardVideoDialog() {
    if (SubscriptionService().isPremium) return;
    final vpn = _vpnProvider;
    if (vpn != null && vpn.isRewardedAdReady) {
      // تأخير بسيط عشان الـ TUN يستقر قبل ما يبدا الإعلان
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        print('[HomePage] Unity Ads is ready, showing video...');
        vpn.showRewardedAd(
        onCompleted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تمت مشاهدة إعلان يونيتي بالكامل! استمتع بالاتصال.',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
        onCancelled: () {
          vpn.toggleVpn();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم قطع الاتصال لعدم اكتمال الإعلان.',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      );
      });
    } else {
      print('[HomePage] Unity Ads is not ready, bypassing dialog and connecting directly.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم الاتصال بنجاح!',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _RewardVideoDialog extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onCancelled;

  const _RewardVideoDialog({
    required this.onCompleted,
    required this.onCancelled,
  });

  @override
  State<_RewardVideoDialog> createState() => _RewardVideoDialogState();
}

class _RewardVideoDialogState extends State<_RewardVideoDialog> {
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        widget.onCompleted();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleClose() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تنبيه',
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'إذا خرجت الآن فسيتم فصل اتصال الـ VPN. هل أنت متأكد من الخروج؟',
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إكمال المشاهدة', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onCancelled();
            },
            child: const Text('قطع الاتصال والخروج', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (30 - _secondsLeft) / 30.0;
    return WillPopScope(
      onWillPop: () async {
        _handleClose();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
                      ),
                      child: const Icon(
                        Icons.play_circle_filled,
                        size: 80,
                        color: Colors.cyan,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'جاري تشغيل إعلان المكافأة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يرجى عدم إغلاق هذه الصفحة لتجنب قطع الاتصال',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'متبقي $_secondsLeft ثانية',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: InkWell(
                  onTap: _handleClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
