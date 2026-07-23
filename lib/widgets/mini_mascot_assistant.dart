import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An ultra-fun, interactive 3D Cyber-Pet mascot for Mobile & Tablet screens.
/// Features:
/// - Smooth touch-drag physics (tilts & reacts while dragging around screen).
/// - Tap to spin/flip, jump, pop heart/star sparkles & speak fun quotes.
/// - Dynamic expressions: Sleepy Idle, Focus Connecting, Happy Connected.
/// - Floating neon particles & aura glow.
class DraggableMiniMascot extends StatefulWidget {
  final String status;
  final VoidCallback? onTap;

  const DraggableMiniMascot({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  State<DraggableMiniMascot> createState() => _DraggableMiniMascotState();
}

class _DraggableMiniMascotState extends State<DraggableMiniMascot>
    with TickerProviderStateMixin {
  Offset? _pos;
  Offset _dragVelocity = Offset.zero;
  bool _isDragging = false;

  late AnimationController _idleController;
  late AnimationController _spinController;
  late AnimationController _jumpController;
  late AnimationController _particleController;
  late AnimationController _blinkController;
  late AnimationController _popController;

  bool _showBubble = true;
  String _bubbleText = '';
  Timer? _bubbleTimer;

  final List<String> _connectedQuotes = [
    'محمي بأمان! 🛡️',
    'السرعة أسطورية! ⚡',
    'تصفح بكل حريّة! 🚀',
    'أنا حارسك الشخصي! 👑',
    'تشفير 100% رائع! 💎',
  ];

  final List<String> _disconnectedQuotes = [
    'جاهز للحماية! 🚀',
    'اضغط للاتصال! 💡',
    'أنا مساعدك الكيوت! 🤖',
    'حركني في أي مكان! 🖐️',
    'احمِ اتصالك الآن! 🛡️',
  ];

  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _startBlinkLoop();
    _updateBubbleText();
    _popBubbleTimer();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2500 + math.Random().nextInt(2500)));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant DraggableMiniMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateBubbleText();
      _triggerTapAction();
    }
  }

  void _updateBubbleText() {
    if (widget.status == 'CONNECTED') {
      _bubbleText = _connectedQuotes[_quoteIndex % _connectedQuotes.length];
    } else if (widget.status == 'CONNECTING') {
      _bubbleText = 'جاري الاتصال... ⚡';
    } else {
      _bubbleText = _disconnectedQuotes[_quoteIndex % _disconnectedQuotes.length];
    }
  }

  void _popBubbleTimer() {
    setState(() => _showBubble = true);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBubble = false);
    });
  }

  void _triggerTapAction() {
    _quoteIndex++;
    _updateBubbleText();
    _popBubbleTimer();

    // Trigger jump & spin & particle pop!
    _jumpController.forward(from: 0.0).then((_) {
      if (mounted) _jumpController.reverse();
    });
    _spinController.forward(from: 0.0);
    _popController.forward(from: 0.0);

    widget.onTap?.call();
  }

  @override
  void dispose() {
    _idleController.dispose();
    _spinController.dispose();
    _jumpController.dispose();
    _particleController.dispose();
    _blinkController.dispose();
    _popController.dispose();
    _bubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final defaultX = 16.0;
    final defaultY = screenSize.height - padding.bottom - 150.0;
    final currentPos = _pos ?? Offset(defaultX, defaultY);

    return Positioned(
      left: currentPos.dx,
      top: currentPos.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            _dragVelocity = details.delta;
            final newX = (currentPos.dx + details.delta.dx).clamp(
              4.0,
              screenSize.width - 86.0,
            );
            final newY = (currentPos.dy + details.delta.dy).clamp(
              padding.top + 40.0,
              screenSize.height - padding.bottom - 110.0,
            );
            _pos = Offset(newX, newY);
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
            _dragVelocity = Offset.zero;
          });
        },
        onTap: _triggerTapAction,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _idleController,
            _spinController,
            _jumpController,
            _particleController,
            _blinkController,
            _popController,
          ]),
          builder: (context, child) {
            final idle = _idleController.value;
            final spin = CurvedAnimation(parent: _spinController, curve: Curves.elasticOut).value;
            final jump = CurvedAnimation(parent: _jumpController, curve: Curves.easeOutBack).value;
            final floatY = math.sin(idle * math.pi * 2) * 5.0 - (jump * 18.0);

            final rotY = (spin * math.pi * 2) + (_dragVelocity.dx * 0.04);
            final rotX = -_dragVelocity.dy * 0.04;
            final scale = _isDragging ? 1.15 : (1.0 + jump * 0.1);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Speech Bubble
                Positioned(
                  bottom: 84,
                  left: -10,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showBubble && !_isDragging ? 1.0 : 0.0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: _showBubble && !_isDragging ? 1.0 : 0.6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.status == 'CONNECTED'
                                ? const Color(0xFF30D158)
                                : const Color(0xFF38BDF8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _bubbleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Popping Heart/Star Burst Particles on Tap
                if (_popController.value > 0 && _popController.value < 1)
                  _buildBurstParticles(_popController.value),

                // Main Mascot Character Render
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    // ignore: deprecated_member_use
                    ..translate(0.0, floatY, 0.0)
                    // ignore: deprecated_member_use
                    ..scale(scale)
                    ..rotateY(rotY)
                    ..rotateX(rotX),
                  child: CustomPaint(
                    size: const Size(82, 82),
                    painter: _MiniPetPainter(
                      status: widget.status,
                      idle: idle,
                      dragDelta: _dragVelocity,
                      isDragging: _isDragging,
                      blink: _blinkController.value,
                      spin: spin,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBurstParticles(double progress) {
    return Stack(
      children: List.generate(6, (i) {
        final angle = (i / 6) * math.pi * 2;
        final dist = progress * 45;
        final x = math.cos(angle) * dist;
        final y = math.sin(angle) * dist - 20;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: opacity,
            child: Icon(
              i % 2 == 0 ? Icons.star_rounded : Icons.favorite_rounded,
              size: 14 * (1.0 - progress * 0.3),
              color: i % 2 == 0 ? const Color(0xFFFFD700) : const Color(0xFFFF4757),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DEDICATED MINI PET PAINTER (Optimized & Super Cute)
// ═══════════════════════════════════════════════════════════════
class _MiniPetPainter extends CustomPainter {
  final String status;
  final double idle;
  final Offset dragDelta;
  final bool isDragging;
  final double blink;
  final double spin;

  _MiniPetPainter({
    required this.status,
    required this.idle,
    required this.dragDelta,
    required this.isDragging,
    required this.blink,
    required this.spin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final isConnected = status == 'CONNECTED';
    final isConnecting = status == 'CONNECTING';

    Color themeColor = const Color(0xFF38BDF8); // Cyan
    if (isConnected) themeColor = const Color(0xFF30D158); // Green
    if (isConnecting) themeColor = const Color(0xFFFF9500); // Amber

    // ─── 1. GROUND SHADOW ───────────
    final shadowW = 44.0 * (1.0 - math.sin(idle * math.pi * 2) * 0.1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height - 4), width: shadowW, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ─── 2. NEON AURA GLOW ───────────
    final auraSize = 64.0 + math.sin(idle * math.pi * 2) * 6;
    canvas.drawCircle(
      Offset(cx, cy - 2),
      auraSize / 2,
      Paint()
        ..color = themeColor.withValues(alpha: isConnected ? 0.35 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ─── 3. ANTIMATION EARS ──────────
    final earTilt = dragDelta.dx * 0.3 + math.sin(idle * math.pi * 2) * 3;

    // Left Ear
    final leftEar = Path()
      ..moveTo(cx - 20, cy - 18)
      ..lineTo(cx - 32 + earTilt, cy - 36)
      ..lineTo(cx - 8, cy - 24)
      ..close();
    canvas.drawPath(leftEar, Paint()..color = const Color(0xFF1E293B));
    canvas.drawPath(leftEar, Paint()..color = themeColor.withValues(alpha: 0.6));

    // Right Ear
    final rightEar = Path()
      ..moveTo(cx + 20, cy - 18)
      ..lineTo(cx + 32 + earTilt, cy - 36)
      ..lineTo(cx + 8, cy - 24)
      ..close();
    canvas.drawPath(rightEar, Paint()..color = const Color(0xFF1E293B));
    canvas.drawPath(rightEar, Paint()..color = themeColor.withValues(alpha: 0.6));

    // ─── 4. CUTE COMPUTER BODY ───────
    final bodyW = 54.0;
    final bodyH = 46.0;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 2), width: bodyW, height: bodyH),
      const Radius.circular(16),
    );

    // Outer Dark Metallic Casing
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bodyRect.outerRect),
    );

    // Casing Highlight Rim Light
    canvas.drawRRect(
      bodyRect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = themeColor.withValues(alpha: 0.5),
    );

    // ─── 5. SCREEN FACE GLASS ────────
    final screenW = 44.0;
    final screenH = 36.0;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 2), width: screenW, height: screenH),
      const Radius.circular(11),
    );
    canvas.drawRRect(screenRect, Paint()..color = const Color(0xFF0D1117));

    // Screen Inner Tint
    canvas.drawRRect(
      screenRect,
      Paint()..color = themeColor.withValues(alpha: 0.08),
    );

    // ─── 6. EXPRESSIVE DIGITAL EYES & MOUTH ───
    final eyeDx = (dragDelta.dx * 0.15).clamp(-5.0, 5.0);
    final eyeDy = (dragDelta.dy * 0.15).clamp(-4.0, 4.0);
    final faceCx = cx + eyeDx;
    final faceCy = cy - 2 + eyeDy;

    final eyeStroke = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    if (isConnected) {
      // HAPPY FACIAL EXPRESSION (^‿^)
      canvas.drawArc(
        Rect.fromCenter(center: Offset(faceCx - 10, faceCy - 3), width: 10, height: 8),
        math.pi * 1.1, math.pi * 0.8, false, eyeStroke,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(faceCx + 10, faceCy - 3), width: 10, height: 8),
        math.pi * 1.1, math.pi * 0.8, false, eyeStroke,
      );
      // Cute Smile
      canvas.drawArc(
        Rect.fromCenter(center: Offset(faceCx, faceCy + 5), width: 10, height: 6),
        0.2, math.pi - 0.4, false, eyeStroke..strokeWidth = 2.2,
      );
    } else if (isConnecting) {
      // FOCUS LOADING FACE (>_<)
      canvas.drawLine(Offset(faceCx - 14, faceCy - 6), Offset(faceCx - 7, faceCy - 2), eyeStroke);
      canvas.drawLine(Offset(faceCx - 14, faceCy + 2), Offset(faceCx - 7, faceCy - 2), eyeStroke);
      canvas.drawLine(Offset(faceCx + 14, faceCy - 6), Offset(faceCx + 7, faceCy - 2), eyeStroke);
      canvas.drawLine(Offset(faceCx + 14, faceCy + 2), Offset(faceCx + 7, faceCy - 2), eyeStroke);
      // O mouth
      canvas.drawCircle(Offset(faceCx, faceCy + 5), 3, eyeStroke..strokeWidth = 2.0);
    } else {
      // CUTE BLINKING IDLE EYES (•‿•)
      final eyeH = 10.0 * (1.0 - blink * 0.85);
      final eyeFill = Paint()..color = themeColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(faceCx - 10, faceCy - 2), width: 6, height: eyeH),
          Radius.circular(eyeH / 2),
        ),
        eyeFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(faceCx + 10, faceCy - 2), width: 6, height: eyeH),
          Radius.circular(eyeH / 2),
        ),
        eyeFill,
      );

      // Eye White Catchlight
      if (blink < 0.3) {
        canvas.drawCircle(Offset(faceCx - 11, faceCy - 4), 1.5, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(faceCx + 9, faceCy - 4), 1.5, Paint()..color = Colors.white);
      }

      // Small Smile
      canvas.drawArc(
        Rect.fromCenter(center: Offset(faceCx, faceCy + 5), width: 8, height: 5),
        0.2, math.pi - 0.4, false, eyeStroke..strokeWidth = 2.0,
      );
    }

    // ─── 7. CHEEK BLUSH ───────────────
    final blush = Paint()..color = const Color(0xFFFF6B81).withValues(alpha: 0.5);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 15, cy + 6), width: 6, height: 3), blush);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 15, cy + 6), width: 6, height: 3), blush);

    // ─── 8. DANGING FEET ──────────────
    final legWiggle = math.sin(idle * math.pi * 2) * 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 12 + legWiggle, cy + 22), width: 10, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 12 - legWiggle, cy + 22), width: 10, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF475569),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniPetPainter old) => true;
}
