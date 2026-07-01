import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/theme_provider.dart';

class ConnectButton extends StatelessWidget {
  final bool isConnected;
  final bool isButtonLoading;
  final bool isAdLoading;
  final String buttonText;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;
  final bool isConnectionVerified;
  final int connectionTime;

  const ConnectButton({
    super.key,
    required this.isConnected,
    required this.isButtonLoading,
    required this.isAdLoading,
    required this.buttonText,
    required this.pulseAnimation,
    required this.onTap,
    required this.isConnectionVerified,
    required this.connectionTime,
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
            if (isConnected || isButtonLoading) {
              scale = pulseAnimation.value;
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glowing aura
                Container(
                  width: 190 * scale,
                  height: 190 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? activeColor.withOpacity(0.12)
                        : isButtonLoading
                            ? activeColor.withOpacity(0.06)
                            : Colors.transparent,
                  ),
                ),
                // Inner button
                GestureDetector(
                  onTap: isButtonLoading ? null : onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isConnected
                          ? LinearGradient(
                              colors: [activeColor, activeColor.withBlue(255)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: themeProvider.isDarkMode
                                  ? [
                                      const Color(0xFF2C2C2E),
                                      const Color(0xFF1C1C1E)
                                    ]
                                  : [Colors.white, const Color(0xFFE5E5EA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: isConnected
                              ? activeColor.withOpacity(0.4)
                              : Colors.black.withOpacity(
                                  themeProvider.isDarkMode ? 0.3 : 0.08),
                          blurRadius: isConnected ? 25 : 15,
                          spreadRadius: isConnected ? 2 : 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: isConnected
                            ? Colors.white.withOpacity(0.2)
                            : themeProvider.isDarkMode
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.03),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isButtonLoading
                          ? CircularProgressIndicator(
                              color: isConnected ? Colors.white : activeColor,
                              strokeWidth: 4,
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 55,
                              color: isConnected ? Colors.white : inactiveColor,
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        // Status Text
        Text(
          isAdLoading && !isConnected ? 'جاري تحميل الإعلان...' : buttonText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 22,
            color: isConnected ? activeColor : inactiveColor,
          ),
        ),
        const SizedBox(height: 12),
        // Timer Widget in an elegant capsule
        if (isConnected && isConnectionVerified)
          AnimatedOpacity(
            opacity: (isConnected && isConnectionVerified) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
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
          ),
      ],
    );
  }
}
