import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/theme_provider.dart';

class ConnectButton extends StatelessWidget {
  final bool isConnected;
  final bool isFullyConnected;
  final bool isButtonLoading;
  final bool isAdLoading;
  final String buttonText;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;
  final VoidCallback? onExtend;
  final bool isConnectionVerified;
  final int connectionTime;
  final bool isExtended;
  final bool isPremium;

  const ConnectButton({
    super.key,
    required this.isConnected,
    required this.isFullyConnected,
    required this.isButtonLoading,
    required this.isAdLoading,
    required this.buttonText,
    required this.pulseAnimation,
    required this.onTap,
    this.onExtend,
    required this.isConnectionVerified,
    required this.connectionTime,
    this.isExtended = false,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final Color activeColor = theme.colorScheme.primary; // Apple Blue
    final Color inactiveColor =
        themeProvider.isDarkMode ? Colors.white : Colors.black87;

    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            double scale = 1.0;
            if (isFullyConnected) {
              scale = pulseAnimation.value;
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                // Soft radial breath glow for negative space accent
                Container(
                  width: 280 * scale,
                  height: 280 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isFullyConnected
                          ? [
                              activeColor.withOpacity(0.70), // Highly intense glow when connected
                              activeColor.withOpacity(0.25),
                              Colors.transparent,
                            ]
                          : isConnected
                              ? [
                                  activeColor.withOpacity(0.25), // Softer glow while connecting
                                  activeColor.withOpacity(0.05),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                    ),
                  ),
                ),
                // The main physical/glassy interactive orb button
                GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isFullyConnected
                          ? LinearGradient(
                              colors: [
                                activeColor,
                                const Color(0xFF5856D6), // Apple Indigo/Purple accent
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: themeProvider.isDarkMode
                                  ? [
                                      const Color(0xFF181926), // Deep matte slate/charcoal
                                      const Color(0xFF0F1018),
                                    ]
                                  : [
                                      Colors.white,
                                      const Color(0xFFF2F2F7),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      boxShadow: [
                        // Soft wide outer neon glow
                        BoxShadow(
                          color: isFullyConnected
                              ? activeColor.withOpacity(0.55)
                              : Colors.black.withOpacity(
                                  themeProvider.isDarkMode ? 0.35 : 0.04),
                          blurRadius: isFullyConnected ? 55 : 15,
                          spreadRadius: isFullyConnected ? 4 : 0,
                          offset: const Offset(0, 8),
                        ),
                        // Intense inner neon core glow for dopamine boost
                        if (isFullyConnected)
                          BoxShadow(
                            color: const Color(0xFF5856D6).withOpacity(0.65),
                            blurRadius: 25,
                            spreadRadius: 1,
                          ),
                      ],
                      border: Border.all(
                        color: isFullyConnected
                            ? const Color(0xFF007AFF) // Strong Neon Blue line on the button itself
                            : themeProvider.isDarkMode
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.03),
                        width: 2.2, // Strong neon line thickness
                      ),
                    ),
                    child: Center(
                      child: isButtonLoading
                          ? CircularProgressIndicator(
                              color: isFullyConnected ? Colors.white : activeColor,
                              strokeWidth: 4.0,
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 54,
                              color: isFullyConnected ? Colors.white : inactiveColor.withOpacity(0.7),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (isFullyConnected && isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6C453).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF6C453).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.all_inclusive_rounded, size: 16, color: Color(0xFFF6C453)),
                SizedBox(width: 6),
                Text(
                  'غير محدود',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF6C453),
                  ),
                ),
              ],
            ),
          )
        else if (isFullyConnected)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'متبقي ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: activeColor,
                    ),
                  ),
                  Text(
                    '${(connectionTime ~/ 3600).toString().padLeft(2, '0')}:${((connectionTime % 3600) ~/ 60).toString().padLeft(2, '0')}:${(connectionTime % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              isAdLoading && !isConnected ? 'جاري تحميل الإعلان...' : buttonText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontSize: 22,
                color: isConnected ? activeColor : inactiveColor,
              ),
            ),
          ),
        if (isFullyConnected && !isPremium && !isExtended && onExtend != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: onExtend,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF9500),
                      const Color(0xFFFF6B35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'مدد لـ 24 ساعة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
