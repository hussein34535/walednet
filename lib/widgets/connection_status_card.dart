import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/theme_provider.dart';

class ConnectionStatusCard extends StatelessWidget {
  final String vpnStatus;
  final bool isTestingSpeed;
  final double? downloadSpeed;
  final double? uploadSpeed;
  final int liveDownlink;
  final int liveUplink;
  final VoidCallback onSpeedTestPressed;

  const ConnectionStatusCard({
    super.key,
    required this.vpnStatus,
    required this.isTestingSpeed,
    this.downloadSpeed,
    this.uploadSpeed,
    this.liveDownlink = 0,
    this.liveUplink = 0,
    required this.onSpeedTestPressed,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.themeData;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحميل (Download)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildSpeedInfoWidget('Download'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: themeProvider.isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'رفع (Upload)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildSpeedInfoWidget('Upload'),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.secondary.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: vpnStatus == 'CONNECTED'
                    ? Column(
                        children: [
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: themeProvider.isDarkMode
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.06),
                          ),
                          const SizedBox(height: 16),
                          _buildSpeedTestButton(theme, themeProvider),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedTestButton(ThemeData theme, ThemeProvider themeProvider) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isTestingSpeed ? null : onSpeedTestPressed,
        icon: isTestingSpeed
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.speed_rounded, size: 20),
        label: Text(
          isTestingSpeed ? 'جاري القياس...' : 'فحص سرعة الاتصال',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  static String formatBitrate(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  Widget _buildSpeedInfoWidget(String label) {
    if (isTestingSpeed) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      );
    }

    String textToShow = "-";
    double? result = (label == 'Download') ? downloadSpeed : uploadSpeed;

    if (result != null) {
      if (result == -1) {
        textToShow = "Error";
      } else {
        textToShow = '${result.toStringAsFixed(2)} Mbps';
      }
    } else {
      final liveBps = (label == 'Download') ? liveDownlink : liveUplink;
      if (liveBps > 0) {
        textToShow = formatBitrate(liveBps);
      }
    }

    return Text(
      textToShow,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        letterSpacing: 0.2,
      ),
    );
  }
}
