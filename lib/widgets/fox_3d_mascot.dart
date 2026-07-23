import 'dart:math' as math;
import 'package:flutter/material.dart';

class Fox3dMascot extends StatefulWidget {
  final String status; // 'DISCONNECTED', 'CONNECTING', 'CONNECTED'
  final bool isHovered;
  final VoidCallback? onTap;

  const Fox3dMascot({
    super.key,
    required this.status,
    this.isHovered = false,
    this.onTap,
  });

  @override
  State<Fox3dMascot> createState() => _Fox3dMascotState();
}

class _Fox3dMascotState extends State<Fox3dMascot>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _spinController;
  late AnimationController _particleController;

  Offset _mousePos = Offset.zero;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    _spinController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerEvent event, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = (event.localPosition.dx - center.dx) / (size.width / 2);
    final dy = (event.localPosition.dy - center.dy) / (size.height / 2);
    setState(() {
      _mousePos = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
      _isInteracting = true;
    });
  }

  void _onPointerExit() {
    setState(() {
      _mousePos = Offset.zero;
      _isInteracting = false;
    });
  }

  void _triggerClickAnimation() {
    if (!_spinController.isAnimating) {
      _spinController.forward(from: 0.0);
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == 'CONNECTED';
    final isConnecting = widget.status == 'CONNECTING';

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          onHover: (e) => _onPointerMove(e, size),
          onExit: (_) => _onPointerExit(),
          child: GestureDetector(
            onTap: _triggerClickAnimation,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _idleController,
                _spinController,
                _particleController,
              ]),
              builder: (context, child) {
                final idleValue = _idleController.value;
                final spinProgress = CurvedAnimation(
                  parent: _spinController,
                  curve: Curves.elasticOut,
                ).value;

                // 3D Perspective Rotation Angles
                final rotY = (_mousePos.dx * 0.35) + (spinProgress * math.pi * 2);
                final rotX = (-_mousePos.dy * 0.25) + math.sin(idleValue * math.pi * 2) * 0.05;
                final floatY = math.sin(idleValue * math.pi * 2) * (isConnected ? 12 : 6);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dynamic 3D Glow Aura & Shield Rings
                    _buildEnergyField(isConnected, isConnecting, idleValue),

                    // Particle Sparkles
                    _buildParticles(_particleController.value, isConnected),

                    // 3D Fox Mascot Body Stage
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015) // 3D Perspective Depth
                        ..translate(0.0, floatY, 0.0)
                        ..rotateY(rotY)
                        ..rotateX(rotX),
                      child: CustomPaint(
                        size: Size(
                          math.min(constraints.maxWidth * 0.85, 340),
                          math.min(constraints.maxHeight * 0.75, 340),
                        ),
                        painter: Fox3dPainter(
                          status: widget.status,
                          idleValue: idleValue,
                          mousePos: _mousePos,
                          isHovered: _isInteracting || widget.isHovered,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnergyField(bool isConnected, bool isConnecting, double idleValue) {
    Color glowColor = const Color(0xFF007AFF); // Default Blue
    if (isConnected) glowColor = const Color(0xFF30D158); // Emerald Green
    if (isConnecting) glowColor = const Color(0xFFFF9500); // Warm Gold

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: isConnected ? 280 : (isConnecting ? 250 : 220),
      height: isConnected ? 280 : (isConnecting ? 250 : 220),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            glowColor.withValues(alpha: isConnected ? 0.35 : (isConnecting ? 0.25 : 0.15)),
            glowColor.withValues(alpha: 0.0),
          ],
          stops: const [0.2, 1.0],
        ),
      ),
    );
  }

  Widget _buildParticles(double progress, bool isConnected) {
    if (!isConnected) return const SizedBox.shrink();

    final particles = List.generate(6, (index) {
      final angle = (index / 6) * math.pi * 2 + (progress * math.pi * 2);
      final radius = 110.0 + math.sin(progress * math.pi * 4 + index) * 15;
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius - (progress * 20);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF30D158).withValues(alpha: 0.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF30D158).withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    });

    return Stack(children: particles);
  }
}

/// 3D Vector Fox Mascot Custom Painter
class Fox3dPainter extends CustomPainter {
  final String status;
  final double idleValue;
  final Offset mousePos;
  final bool isHovered;

  Fox3dPainter({
    required this.status,
    required this.idleValue,
    required this.mousePos,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final isConnected = status == 'CONNECTED';
    final isConnecting = status == 'CONNECTING';

    // Base Paints & Colors
    final foxOrange = isConnected ? const Color(0xFFFF6D00) : const Color(0xFFFF5722);
    final foxDarkOrange = const Color(0xFFE64A19);
    final foxCream = const Color(0xFFFFF3E0);
    final foxEarInner = const Color(0xFFFFAB91);
    final foxNose = const Color(0xFF212121);
    final mainGlow = isConnected
        ? const Color(0xFF30D158)
        : (isConnecting ? const Color(0xFFFF9500) : const Color(0xFF007AFF));

    // Shadow on Ground Stage
    final shadowScale = 1.0 - (math.sin(idleValue * math.pi * 2) * 0.08);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 25),
        width: 140 * shadowScale,
        height: 28 * shadowScale,
      ),
      shadowPaint,
    );

    // --- 1. FLUFFY 3D TAIL ---
    final tailWiggle = math.sin(idleValue * math.pi * 2) * (isConnected ? 0.25 : 0.12);
    final tailPath = Path()
      ..moveTo(center.dx + 40, center.dy + 40)
      ..cubicTo(
        center.dx + 110 + (tailWiggle * 30), center.dy + 30 + (tailWiggle * 20),
        center.dx + 120 + (tailWiggle * 40), center.dy - 50,
        center.dx + 70 + (tailWiggle * 20), center.dy - 80,
      )
      ..cubicTo(
        center.dx + 40, center.dy - 60,
        center.dx + 30, center.dy,
        center.dx + 40, center.dy + 40,
      );

    final tailGradient = Paint()
      ..shader = LinearGradient(
        colors: [foxDarkOrange, foxOrange, foxCream],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(tailPath, tailGradient);

    // --- 2. FOX 3D BODY ---
    final bodyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 45),
      width: 115,
      height: 100,
    );
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: [foxOrange, foxDarkOrange],
      ).createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(50)),
      bodyPaint,
    );

    // Chest White Fluff
    final chestPath = Path()
      ..moveTo(center.dx - 32, center.dy + 15)
      ..quadraticBezierTo(center.dx, center.dy + 85, center.dx + 32, center.dy + 15)
      ..quadraticBezierTo(center.dx, center.dy + 35, center.dx - 32, center.dy + 15);
    final chestPaint = Paint()..color = foxCream;
    canvas.drawPath(chestPath, chestPaint);

    // --- 3. 3D HEAD & EARS ---
    final headCenter = Offset(center.dx, center.dy - 20);

    // EARS (Left & Right)
    final earEarTilt = math.sin(idleValue * math.pi * 2) * 4;
    // Left Ear
    final leftEar = Path()
      ..moveTo(headCenter.dx - 48, headCenter.dy - 20)
      ..lineTo(headCenter.dx - 75 + earEarTilt, headCenter.dy - 95)
      ..lineTo(headCenter.dx - 18, headCenter.dy - 55)
      ..close();
    canvas.drawPath(leftEar, Paint()..color = foxDarkOrange);

    final leftEarInner = Path()
      ..moveTo(headCenter.dx - 45, headCenter.dy - 25)
      ..lineTo(headCenter.dx - 68 + earEarTilt, headCenter.dy - 85)
      ..lineTo(headCenter.dx - 22, headCenter.dy - 50)
      ..close();
    canvas.drawPath(leftEarInner, Paint()..color = foxEarInner);

    // Right Ear
    final rightEar = Path()
      ..moveTo(headCenter.dx + 48, headCenter.dy - 20)
      ..lineTo(headCenter.dx + 75 - earEarTilt, headCenter.dy - 95)
      ..lineTo(headCenter.dx + 18, headCenter.dy - 55)
      ..close();
    canvas.drawPath(rightEar, Paint()..color = foxOrange);

    final rightEarInner = Path()
      ..moveTo(headCenter.dx + 45, headCenter.dy - 25)
      ..lineTo(headCenter.dx + 68 - earEarTilt, headCenter.dy - 85)
      ..lineTo(headCenter.dx + 22, headCenter.dy - 50)
      ..close();
    canvas.drawPath(rightEarInner, Paint()..color = foxEarInner);

    // HEAD MESH (Stylized Polygon Geometry)
    final headPath = Path()
      ..moveTo(headCenter.dx - 65, headCenter.dy - 35)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy - 70, headCenter.dx + 65, headCenter.dy - 35)
      ..lineTo(headCenter.dx + 70, headCenter.dy)
      ..lineTo(headCenter.dx, headCenter.dy + 60) // Muzzle tip
      ..lineTo(headCenter.dx - 70, headCenter.dy)
      ..close();

    final headGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 0.85,
        colors: [
          foxOrange.withRed(255),
          foxDarkOrange,
        ],
      ).createShader(Rect.fromCircle(center: headCenter, radius: 70));
    canvas.drawPath(headPath, headGradient);

    // White Muzzle Mask
    final muzzlePath = Path()
      ..moveTo(headCenter.dx - 50, headCenter.dy - 5)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy + 15, headCenter.dx + 50, headCenter.dy - 5)
      ..lineTo(headCenter.dx, headCenter.dy + 58)
      ..close();
    canvas.drawPath(muzzlePath, Paint()..color = foxCream);

    // Nose
    final nosePath = Path()
      ..moveTo(headCenter.dx - 10, headCenter.dy + 42)
      ..lineTo(headCenter.dx + 10, headCenter.dy + 42)
      ..lineTo(headCenter.dx, headCenter.dy + 52)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = foxNose);

    // --- 4. EXPRESSIVE EYES (Follows Mouse Cursor & Status) ---
    final pupilOffsetX = mousePos.dx * 6;
    final pupilOffsetY = mousePos.dy * 4;

    if (isConnected) {
      // Happy Closed / Sparkle Eyes ^ ^
      final eyePaint = Paint()
        ..color = mainGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      // Left Arc Eye
      canvas.drawArc(
        Rect.fromCenter(center: Offset(headCenter.dx - 26, headCenter.dy + 5), width: 22, height: 18),
        math.pi * 1.1, math.pi * 0.8, false, eyePaint,
      );
      // Right Arc Eye
      canvas.drawArc(
        Rect.fromCenter(center: Offset(headCenter.dx + 26, headCenter.dy + 5), width: 22, height: 18),
        math.pi * 1.1, math.pi * 0.8, false, eyePaint,
      );
    } else {
      // Round Cute Expressive Eyes
      final eyeBgPaint = Paint()..color = const Color(0xFF1E293B);

      // Left Eye Outer
      canvas.drawCircle(Offset(headCenter.dx - 26, headCenter.dy + 5), 13, eyeBgPaint);
      // Right Eye Outer
      canvas.drawCircle(Offset(headCenter.dx + 26, headCenter.dy + 5), 13, eyeBgPaint);

      // Iris Pupil (follows cursor!)
      final irisPaint = Paint()..color = mainGlow;
      canvas.drawCircle(Offset(headCenter.dx - 26 + pupilOffsetX, headCenter.dy + 5 + pupilOffsetY), 6, irisPaint);
      canvas.drawCircle(Offset(headCenter.dx + 26 + pupilOffsetX, headCenter.dy + 5 + pupilOffsetY), 6, irisPaint);

      // Catchlight Sparkle White Dots
      canvas.drawCircle(Offset(headCenter.dx - 29 + pupilOffsetX, headCenter.dy + 2 + pupilOffsetY), 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(headCenter.dx + 23 + pupilOffsetX, headCenter.dy + 2 + pupilOffsetY), 2.5, Paint()..color = Colors.white);
    }

    // --- 5. HIGH-TECH GAMING HEADPHONES ---
    final bandPath = Path()
      ..moveTo(headCenter.dx - 68, headCenter.dy - 10)
      ..cubicTo(
        headCenter.dx - 65, headCenter.dy - 90,
        headCenter.dx + 65, headCenter.dy - 90,
        headCenter.dx + 68, headCenter.dy - 10,
      );
    final bandPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawPath(bandPath, bandPaint);

    // Ear Cups (Left & Right)
    final cupPaint = Paint()..color = mainGlow;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(headCenter.dx - 68, headCenter.dy - 10), width: 22, height: 38),
        const Radius.circular(8),
      ),
      cupPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(headCenter.dx + 68, headCenter.dy - 10), width: 22, height: 38),
        const Radius.circular(8),
      ),
      cupPaint,
    );
  }

  @override
  bool shouldRepaint(covariant Fox3dPainter oldDelegate) => true;
}
