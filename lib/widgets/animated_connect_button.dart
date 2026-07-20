import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedConnectButton extends StatefulWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  const AnimatedConnectButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  State<AnimatedConnectButton> createState() => _AnimatedConnectButtonState();
}

class _AnimatedConnectButtonState extends State<AnimatedConnectButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(AnimatedConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnecting && !oldWidget.isConnecting) {
      _rotateController.repeat();
    } else if (!widget.isConnecting && oldWidget.isConnecting) {
      _rotateController.stop();
      _rotateController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.55;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isConnecting ? 1.0 : _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.isConnected
                ? AppColors.successGradient
                : widget.isConnecting
                    ? AppColors.primaryGradient
                    : const LinearGradient(
                        colors: [
                          Color(0xFF2D3A5C),
                          Color(0xFF1A2342),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            boxShadow: [
              BoxShadow(
                color: widget.isConnected
                    ? AppColors.success.withOpacity(0.4)
                    : widget.isConnecting
                        ? AppColors.primary.withOpacity(0.4)
                        : AppColors.primary.withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: widget.isConnected ? 8 : 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 2,
              ),
            ),
            child: Center(
              child: widget.isConnecting
                  ? AnimatedBuilder(
                      animation: _rotateAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotateAnimation.value * 6.283,
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        );
                      },
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isConnected
                              ? Icons.shield_rounded
                              : Icons.power_settings_new_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isConnected ? 'متصل' : 'اضغط للاتصال',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
