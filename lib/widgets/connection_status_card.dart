import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/theme_provider.dart';

class ConnectionStatusCard extends StatelessWidget {
  final String vpnStatus;
  final bool isTestingSpeed;
  final double? downloadSpeed;
  final double? uploadSpeed;
  final VoidCallback onSpeedTestPressed;

  const ConnectionStatusCard({
    super.key,
    required this.vpnStatus,
    required this.isTestingSpeed,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.onSpeedTestPressed,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.themeData;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.04) // Frosted dark glass
                : Colors.white.withOpacity(0.85), // Frosted light glass
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.15 : 0.02),
                blurRadius: 15,
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
                            color: const Color(0xFF007AFF).withOpacity(0.08), // iOS Blue
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF007AFF).withOpacity(0.15),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Color(0xFF007AFF),
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
                                    ?.withOpacity(0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _buildSpeedInfoWidget('Download'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 35,
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
                                    ?.withOpacity(0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _buildSpeedInfoWidget('Upload'),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.08), // iOS Green
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF34C759).withOpacity(0.15),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Color(0xFF34C759),
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
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
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
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isTestingSpeed ? null : onSpeedTestPressed,
        icon: isTestingSpeed
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: themeProvider.isDarkMode
                      ? Colors.white
                      : theme.colorScheme.primary,
                ),
              )
            : const Icon(Icons.speed_rounded, size: 20),
        label: Text(
          isTestingSpeed ? 'جاري القياس...' : 'فحص سرعة الاتصال',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.4),
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          elevation: 0,
          shadowColor: theme.colorScheme.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
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
    }

    return Text(
      textToShow,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}
