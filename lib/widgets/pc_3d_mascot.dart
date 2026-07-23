import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A stunning interactive 3D-style cute computer mascot for the desktop VPN app.
/// Features: smooth mouse-follow, idle breathing/floating, connection-reactive
/// animations, particle effects, neon glow trails, eye expressions, and click reactions.
class Pc3dMascot extends StatefulWidget {
  final String status; // 'DISCONNECTED', 'CONNECTING', 'CONNECTED'
  final bool isHovered;
  final VoidCallback? onTap;

  const Pc3dMascot({
    super.key,
    required this.status,
    this.isHovered = false,
    this.onTap,
  });

  @override
  State<Pc3dMascot> createState() => _Pc3dMascotState();
}

class _Pc3dMascotState extends State<Pc3dMascot>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _bounceController;
  late AnimationController _particleController;
  late AnimationController _blinkController;
  late AnimationController _waveController;
  late AnimationController _glowPulseController;

  Offset _mousePos = Offset.zero;
  Offset _smoothMouse = Offset.zero;
  bool _isInteracting = false;
  String _prevStatus = '';

  @override
  void initState() {
    super.initState();
    // Slow breathing idle float
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    // Click bounce reaction
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Orbiting particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Eye blink cycle
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _startBlinkLoop();

    // Wave/pulse ring on connection
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Glowing pulse for connected state
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2800 + math.Random().nextInt(3000)));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant Pc3dMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && widget.status != _prevStatus) {
      _prevStatus = widget.status;
      // Trigger wave burst on status change
      _waveController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _bounceController.dispose();
    _particleController.dispose();
    _blinkController.dispose();
    _waveController.dispose();
    _glowPulseController.dispose();
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

  void _triggerClick() {
    setState(() {});
    _bounceController.forward(from: 0.0).then((_) {
      if (mounted) setState(() {});
    });
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
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _triggerClick,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _idleController,
                _bounceController,
                _particleController,
                _blinkController,
                _waveController,
                _glowPulseController,
              ]),
              builder: (context, child) {
                // Smooth mouse follow (lerp towards target)
                _smoothMouse = Offset(
                  _smoothMouse.dx + (_mousePos.dx - _smoothMouse.dx) * 0.12,
                  _smoothMouse.dy + (_mousePos.dy - _smoothMouse.dy) * 0.12,
                );

                final idle = _idleController.value;
                final bounce = CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut).value;

                // 3D-style rotation
                final rotY = _smoothMouse.dx * 0.28;
                final rotX = -_smoothMouse.dy * 0.18;
                final floatY = math.sin(idle * math.pi * 2) * (isConnected ? 14 : 7);
                final breathScale = 1.0 + math.sin(idle * math.pi * 2) * 0.015;
                final clickScale = 1.0 + bounce * 0.12;

                final mascotW = math.min(constraints.maxWidth * 0.82, 360.0);
                final mascotH = math.min(constraints.maxHeight * 0.78, 360.0);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background ambient glow
                    _buildAmbientGlow(isConnected, isConnecting, idle),

                    // Wave ring effect on status change
                    _buildWaveRing(isConnected, isConnecting),

                    // Orbiting particles
                    _buildOrbitingParticles(isConnected, isConnecting),

                    // Floating sparkles
                    if (isConnected) _buildFloatingSparkles(idle),

                    // 3D Mascot
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        // ignore: deprecated_member_use
                        ..translate(0.0, floatY, 0.0)
                        // ignore: deprecated_member_use
                        ..scale(breathScale * clickScale)
                        ..rotateY(rotY)
                        ..rotateX(rotX),
                      child: CustomPaint(
                        size: Size(mascotW, mascotH),
                        painter: _Pc3dPainter(
                          status: widget.status,
                          idleValue: idle,
                          mousePos: _smoothMouse,
                          isHovered: _isInteracting || widget.isHovered,
                          blinkValue: _blinkController.value,
                          glowPulse: _glowPulseController.value,
                          clickBounce: bounce,
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

  // ─────────── Ambient Glow ───────────
  Widget _buildAmbientGlow(bool isConnected, bool isConnecting, double idle) {
    Color c = const Color(0xFF38BDF8);
    if (isConnected) c = const Color(0xFF30D158);
    if (isConnecting) c = const Color(0xFFFF9500);

    final pulse = _glowPulseController.value;
    final baseSize = isConnected ? 310.0 : (isConnecting ? 270.0 : 240.0);
    final size = baseSize + pulse * 30;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            c.withValues(alpha: 0.25 + pulse * 0.12),
            c.withValues(alpha: 0.06),
            c.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  // ─────────── Wave Ring Burst ───────────
  Widget _buildWaveRing(bool isConnected, bool isConnecting) {
    final v = _waveController.value;
    if (v == 0 || v == 1) return const SizedBox.shrink();

    Color c = const Color(0xFF38BDF8);
    if (isConnected) c = const Color(0xFF30D158);
    if (isConnecting) c = const Color(0xFFFF9500);

    return Opacity(
      opacity: (1.0 - v) * 0.6,
      child: Container(
        width: 100 + v * 250,
        height: 100 + v * 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: c,
            width: 3.0 * (1.0 - v),
          ),
        ),
      ),
    );
  }

  // ─────────── Orbiting Particles ───────────
  Widget _buildOrbitingParticles(bool isConnected, bool isConnecting) {
    final progress = _particleController.value;
    final count = isConnected ? 12 : (isConnecting ? 8 : 5);
    Color c = const Color(0xFF38BDF8);
    if (isConnected) c = const Color(0xFF30D158);
    if (isConnecting) c = const Color(0xFFFF9500);

    return Stack(
      alignment: Alignment.center,
      children: List.generate(count, (i) {
        final angle = (i / count) * math.pi * 2 + (progress * math.pi * 2);
        final orbitRadius = 125.0 + math.sin(progress * math.pi * 3 + i * 1.5) * 20;
        final dx = math.cos(angle) * orbitRadius;
        final dy = math.sin(angle) * orbitRadius * 0.55; // Elliptical
        final particleSize = 4.0 + math.sin(progress * math.pi * 4 + i) * 2;
        final alpha = 0.4 + math.sin(progress * math.pi * 2 + i * 0.8) * 0.4;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Container(
            width: particleSize,
            height: particleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: alpha.clamp(0.0, 1.0)),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: (alpha * 0.6).clamp(0.0, 1.0)),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─────────── Floating Sparkles ───────────
  Widget _buildFloatingSparkles(double idle) {
    return Stack(
      alignment: Alignment.center,
      children: List.generate(6, (i) {
        final angle = (i / 6) * math.pi * 2;
        final r = 155.0 + math.sin(idle * math.pi * 2 + i * 1.2) * 25;
        final x = math.cos(angle + idle * math.pi) * r;
        final y = math.sin(angle + idle * math.pi) * r * 0.5 - 20;
        final alpha = 0.5 + math.sin(idle * math.pi * 4 + i * 1.3) * 0.5;

        return Transform.translate(
          offset: Offset(x, y),
          child: Icon(
            Icons.auto_awesome,
            size: 10 + math.sin(idle * math.pi * 3 + i) * 4,
            color: const Color(0xFFFFD700).withValues(alpha: alpha.clamp(0.0, 1.0)),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM PAINTER — Cute 3D Computer Mascot
// ═══════════════════════════════════════════════════════════════
class _Pc3dPainter extends CustomPainter {
  final String status;
  final double idleValue;
  final Offset mousePos;
  final bool isHovered;
  final double blinkValue;
  final double glowPulse;
  final double clickBounce;

  _Pc3dPainter({
    required this.status,
    required this.idleValue,
    required this.mousePos,
    required this.isHovered,
    required this.blinkValue,
    required this.glowPulse,
    required this.clickBounce,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final isConnected = status == 'CONNECTED';
    final isConnecting = status == 'CONNECTING';

    // Theme palette
    const bodyDark = Color(0xFF1A1E2E);
    const bodyMid = Color(0xFF252A3A);
    const bodyLight = Color(0xFF333950);
    const screenBg = Color(0xFF0D1117);

    Color accent = const Color(0xFF38BDF8);
    if (isConnected) accent = const Color(0xFF30D158);
    if (isConnecting) accent = const Color(0xFFFF9500);

    Color accentBright = const Color(0xFF7DD3FC);
    if (isConnected) accentBright = const Color(0xFF6EE7A0);
    if (isConnecting) accentBright = const Color(0xFFFFBF47);

    // ─── 1. GROUND SHADOW ─────────────
    final shadowPulse = 1.0 - math.sin(idleValue * math.pi * 2) * 0.1;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 18),
        width: 160 * shadowPulse,
        height: 22 * shadowPulse,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // ─── 2. STAND / NECK ──────────────
    // Slim neck
    final neckPath = Path()
      ..moveTo(cx - 16, cy + 65)
      ..lineTo(cx + 16, cy + 65)
      ..lineTo(cx + 14, cy + 88)
      ..lineTo(cx - 14, cy + 88)
      ..close();
    canvas.drawPath(
      neckPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [bodyLight, bodyDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(cx - 16, cy + 65, 32, 23)),
    );

    // Base stand plate
    final basePath = Path()
      ..moveTo(cx - 48, cy + 88)
      ..quadraticBezierTo(cx, cy + 80, cx + 48, cy + 88)
      ..lineTo(cx + 52, cy + 97)
      ..quadraticBezierTo(cx, cy + 102, cx - 52, cy + 97)
      ..close();
    canvas.drawPath(
      basePath,
      Paint()
        ..shader = LinearGradient(
          colors: [bodyLight, bodyDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(cx - 52, cy + 80, 104, 22)),
    );

    // Base accent LED strip
    canvas.drawLine(
      Offset(cx - 32, cy + 95),
      Offset(cx + 32, cy + 95),
      Paint()
        ..color = accent.withValues(alpha: 0.5 + glowPulse * 0.3)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // ─── 3. CUTE ANTENNA / EARS ───────
    final earWiggle = math.sin(idleValue * math.pi * 2) * 4;
    final mouseEarTilt = mousePos.dx * 5;

    // Left ear
    _drawEar(canvas, cx, cy, -1, earWiggle + mouseEarTilt, bodyMid, accent, accentBright);
    // Right ear
    _drawEar(canvas, cx, cy, 1, -earWiggle + mouseEarTilt, bodyMid, accent, accentBright);

    // ─── 4. MONITOR HEAD ──────────────
    final monitorW = 180.0;
    final monitorH = 148.0;
    final monitorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 4), width: monitorW, height: monitorH),
      const Radius.circular(28),
    );

    // Outer body
    canvas.drawRRect(
      monitorRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.3 + mousePos.dx * 0.2, -0.3 + mousePos.dy * 0.2),
          radius: 1.2,
          colors: [bodyLight, bodyMid, bodyDark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(monitorRect.outerRect),
    );

    // Highlight edge (3D rim light)
    canvas.drawRRect(
      monitorRect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.06),
          ],
        ).createShader(monitorRect.outerRect),
    );

    // Neon accent border glow
    canvas.drawRRect(
      monitorRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.15 + glowPulse * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ─── 5. SCREEN ────────────────────
    final screenW = 152.0;
    final screenH = 118.0;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 4), width: screenW, height: screenH),
      const Radius.circular(18),
    );

    // Screen background
    canvas.drawRRect(screenRect, Paint()..color = screenBg);

    // Screen inner glow
    canvas.drawRRect(
      screenRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(mousePos.dx * 0.3, mousePos.dy * 0.3),
          colors: [
            accent.withValues(alpha: 0.12 + glowPulse * 0.06),
            accent.withValues(alpha: 0.02),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(screenRect.outerRect),
    );

    // Scanline overlay (subtle)
    for (double y = screenRect.outerRect.top + 4; y < screenRect.outerRect.bottom - 4; y += 4) {
      canvas.drawLine(
        Offset(screenRect.outerRect.left + 10, y),
        Offset(screenRect.outerRect.right - 10, y),
        Paint()..color = Colors.white.withValues(alpha: 0.015),
      );
    }

    // ─── 6. FACE EXPRESSION ────────────
    final px = mousePos.dx * 8;
    final py = mousePos.dy * 5;
    final faceCx = cx + px;
    final faceCy = cy - 4 + py;

    if (isConnected) {
      _drawHappyFace(canvas, faceCx, faceCy, accent, accentBright, blinkValue);
    } else if (isConnecting) {
      _drawFocusFace(canvas, faceCx, faceCy, accent, idleValue);
    } else {
      _drawIdleFace(canvas, faceCx, faceCy, accent, accentBright, blinkValue, isHovered);
    }

    // ─── 7. CHEEK BLUSH ───────────────
    final blushAlpha = isHovered ? 0.55 : 0.35;
    final blushPaint = Paint()
      ..color = const Color(0xFFFF6B81).withValues(alpha: blushAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 48 + px, cy + 16 + py), width: 16, height: 8),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 48 + px, cy + 16 + py), width: 16, height: 8),
      blushPaint,
    );

    // ─── 8. CUTE ARMS ─────────────────
    _drawArms(canvas, cx, cy, idleValue, mousePos, accent, isConnected, clickBounce);

    // ─── 9. POWER LED ─────────────────
    final ledColor = isConnected
        ? const Color(0xFF30D158)
        : (isConnecting ? const Color(0xFFFF9500) : const Color(0xFF38BDF8));
    // LED glow
    canvas.drawCircle(
      Offset(cx, cy + 58),
      5,
      Paint()
        ..color = ledColor.withValues(alpha: 0.4 + glowPulse * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // LED dot
    canvas.drawCircle(
      Offset(cx, cy + 58),
      3,
      Paint()..color = ledColor,
    );
    canvas.drawCircle(
      Offset(cx - 0.8, cy + 57),
      1.2,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  // ─────────── EARS ───────────
  void _drawEar(Canvas canvas, double cx, double cy, int side, double tilt,
      Color body, Color accent, Color bright) {
    final s = side.toDouble();
    final tipX = cx + s * 88 + tilt;
    final tipY = cy - 95;

    final ear = Path()
      ..moveTo(cx + s * 50, cy - 58)
      ..quadraticBezierTo(tipX, tipY, cx + s * 28, cy - 72)
      ..close();
    canvas.drawPath(ear, Paint()..color = body);

    // Inner glow
    final innerEar = Path()
      ..moveTo(cx + s * 48, cy - 60)
      ..quadraticBezierTo(tipX - s * 8, tipY + 8, cx + s * 32, cy - 70)
      ..close();
    canvas.drawPath(
      innerEar,
      Paint()..color = accent.withValues(alpha: 0.5),
    );

    // Ear tip glow dot
    canvas.drawCircle(
      Offset(tipX - s * 4, tipY + 6),
      3,
      Paint()
        ..color = bright.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // ─────────── HAPPY FACE (^_^) ───────────
  void _drawHappyFace(Canvas canvas, double fx, double fy,
      Color accent, Color bright, double blink) {
    final eyeStroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    // Happy arc eyes ^_^
    canvas.drawArc(
      Rect.fromCenter(center: Offset(fx - 28, fy - 6), width: 24, height: 18),
      math.pi * 1.05, math.pi * 0.9, false, eyeStroke,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(fx + 28, fy - 6), width: 24, height: 18),
      math.pi * 1.05, math.pi * 0.9, false, eyeStroke,
    );

    // Sparkle dots above eyes ✦
    final sparkle = Paint()..color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(fx - 38, fy - 20), 2.5, sparkle);
    canvas.drawCircle(Offset(fx + 38, fy - 20), 2.5, sparkle);
    canvas.drawCircle(Offset(fx - 42, fy - 14), 1.5, sparkle);
    canvas.drawCircle(Offset(fx + 42, fy - 14), 1.5, sparkle);

    // Wide smile
    canvas.drawArc(
      Rect.fromCenter(center: Offset(fx, fy + 14), width: 26, height: 16),
      0.15, math.pi - 0.3, false, eyeStroke..strokeWidth = 3.5,
    );

    // Tongue peek
    canvas.drawArc(
      Rect.fromCenter(center: Offset(fx + 3, fy + 18), width: 10, height: 8),
      0, math.pi, false,
      Paint()..color = const Color(0xFFFF6B81).withValues(alpha: 0.7),
    );
  }

  // ─────────── FOCUS FACE (> _ <) ───────────
  void _drawFocusFace(Canvas canvas, double fx, double fy,
      Color accent, double idle) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Left Eye - rotating chevron
    final lc = Offset(fx - 28, fy - 4);
    canvas.drawLine(
      Offset(lc.dx - 8, lc.dy - 8),
      Offset(lc.dx + 4, lc.dy),
      paint,
    );
    canvas.drawLine(
      Offset(lc.dx - 8, lc.dy + 8),
      Offset(lc.dx + 4, lc.dy),
      paint,
    );

    // Right Eye - rotating chevron
    final rc = Offset(fx + 28, fy - 4);
    canvas.drawLine(
      Offset(rc.dx + 8, rc.dy - 8),
      Offset(rc.dx - 4, rc.dy),
      paint,
    );
    canvas.drawLine(
      Offset(rc.dx + 8, rc.dy + 8),
      Offset(rc.dx - 4, rc.dy),
      paint,
    );

    // Small "O" mouth with loading dots
    canvas.drawCircle(
      Offset(fx, fy + 14),
      5,
      paint..strokeWidth = 3.0,
    );

    // Loading dots animation
    for (int i = 0; i < 3; i++) {
      final dotAlpha = (math.sin(idle * math.pi * 6 + i * 1.5) + 1) / 2;
      canvas.drawCircle(
        Offset(fx - 10 + i * 10, fy + 30),
        2.5,
        Paint()..color = accent.withValues(alpha: dotAlpha),
      );
    }
  }

  // ─────────── IDLE FACE (• ‿ •) ───────────
  void _drawIdleFace(Canvas canvas, double fx, double fy,
      Color accent, Color bright, double blink, bool hovered) {
    final eyeH = 22.0 * (1.0 - blink * 0.85); // Blink squash

    // Neon glow eyes
    final glowPaint = Paint()
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(fx - 28, fy - 4), width: 16, height: eyeH),
        Radius.circular(eyeH / 2),
      ),
      glowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(fx + 28, fy - 4), width: 16, height: eyeH),
        Radius.circular(eyeH / 2),
      ),
      glowPaint,
    );

    // Core bright eyes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(fx - 28, fy - 4), width: 14, height: eyeH - 2),
        Radius.circular(eyeH / 2),
      ),
      Paint()..color = bright,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(fx + 28, fy - 4), width: 14, height: eyeH - 2),
        Radius.circular(eyeH / 2),
      ),
      Paint()..color = bright,
    );

    // Eye white catchlights
    if (blink < 0.3) {
      canvas.drawCircle(Offset(fx - 31, fy - 9), 3.5, Paint()..color = Colors.white.withValues(alpha: 0.85));
      canvas.drawCircle(Offset(fx + 25, fy - 9), 3.5, Paint()..color = Colors.white.withValues(alpha: 0.85));
      canvas.drawCircle(Offset(fx - 27, fy - 3), 1.8, Paint()..color = Colors.white.withValues(alpha: 0.5));
      canvas.drawCircle(Offset(fx + 29, fy - 3), 1.8, Paint()..color = Colors.white.withValues(alpha: 0.5));
    }

    // Cute smile
    final mouthPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final smileWidth = hovered ? 22.0 : 16.0;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(fx, fy + 14), width: smileWidth, height: 12),
      0.2, math.pi - 0.4, false, mouthPaint,
    );
  }

  // ─────────── CUTE ARMS ───────────
  void _drawArms(Canvas canvas, double cx, double cy, double idle,
      Offset mouse, Color accent, bool connected, double clickBounce) {
    final armWave = math.sin(idle * math.pi * 2) * 6;
    final armPaint = Paint()
      ..color = const Color(0xFF333950)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Left arm
    final lHandX = cx - 92 + mouse.dx * 4;
    final lHandY = cy + 18 + armWave + clickBounce * -15;

    final leftArm = Path()
      ..moveTo(cx - 88, cy + 5)
      ..quadraticBezierTo(
        cx - 100, cy + 10 + armWave,
        lHandX, lHandY,
      );
    canvas.drawPath(leftArm, armPaint);

    // Left hand (circle)
    canvas.drawCircle(
      Offset(lHandX, lHandY),
      8,
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawCircle(
      Offset(lHandX, lHandY),
      8,
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Right arm
    final rHandX = cx + 92 + mouse.dx * 4;
    final rHandY = cy + 18 - armWave + clickBounce * -15;

    final rightArm = Path()
      ..moveTo(cx + 88, cy + 5)
      ..quadraticBezierTo(
        cx + 100, cy + 10 - armWave,
        rHandX, rHandY,
      );
    canvas.drawPath(rightArm, armPaint);

    // Right hand
    canvas.drawCircle(
      Offset(rHandX, rHandY),
      8,
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawCircle(
      Offset(rHandX, rHandY),
      8,
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Wave gesture on connected
    if (connected) {
      // Right hand waving higher
      final waveExtra = math.sin(idle * math.pi * 4) * 12;
      canvas.drawCircle(
        Offset(rHandX + 2, rHandY - 6 + waveExtra),
        3,
        Paint()..color = accent.withValues(alpha: 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Pc3dPainter old) => true;
}
