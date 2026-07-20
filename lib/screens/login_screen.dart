import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoggedIn) {
        _navigateToHome(context);
      }
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.themeData;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A84FF), Color(0xFF5856D6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A84FF).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'WaledNet',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin ? 'مرحباً بعودتك' : 'أنشئ حسابك',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 36),

                    if (authProvider.errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          authProvider.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'البريد الإلكتروني',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                fontSize: 14,
                                fontFamily: 'Cairo',
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'يرجى إدخال البريد الإلكتروني'
                                : !v.contains('@')
                                    ? 'بريد إلكتروني غير صالح'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            textAlign: TextAlign.right,
                            obscureText: _obscurePassword,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'كلمة المرور',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                fontSize: 14,
                                fontFamily: 'Cairo',
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'كلمة المرور 6 أحرف على الأقل'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _isLogin
                                ? _handleLogin(authProvider)
                                : _handleRegister(authProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'أو',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _handleGoogleSignIn(authProvider),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GoogleIcon(),
                            const SizedBox(width: 10),
                            const Text(
                              'Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin
                              ? 'ليس لديك حساب؟ '
                              : 'لديك حساب بالفعل؟ ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'أنشئ حساب' : 'سجّل الدخول',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await auth.signInWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    if (success && mounted) _navigateToHome(context);
  }

  Future<void> _handleRegister(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await auth.registerWithEmail(
      _emailController.text,
      _passwordController.text,
      '',
    );
    if (success && mounted) _navigateToHome(context);
  }

  Future<void> _handleGoogleSignIn(AuthProvider auth) async {
    final success = await auth.signInWithGoogle();
    if (success && mounted) _navigateToHome(context);
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/home');
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final s = size.width / 24;
    final cx = 12 * s;
    final cy = 12 * s;
    final r = 11.5 * s;

    paint.color = const Color(0xFF4285F4);
    canvas.drawCircle(Offset(cx, cy), r, paint);

    final whitePaint = Paint()..style = PaintingStyle.fill;
    whitePaint.color = Colors.white;
    final gPath = Path()
      ..moveTo(cx + 0.5 * s, cy - 6 * s)
      ..lineTo(cx + 7 * s, cy - 6 * s)
      ..lineTo(cx + 7 * s, cy - 2 * s)
      ..lineTo(cx + 3 * s, cy - 2 * s)
      ..lineTo(cx + 3 * s, cy + 1 * s)
      ..lineTo(cx + 6.5 * s, cy + 1 * s)
      ..lineTo(cx + 6.5 * s, cy + 3 * s)
      ..lineTo(cx + 3 * s, cy + 3 * s)
      ..lineTo(cx + 3 * s, cy + 6 * s)
      ..lineTo(cx - 1 * s, cy + 6 * s)
      ..lineTo(cx - 1 * s, cy - 2 * s)
      ..lineTo(cx + 0.5 * s, cy - 6 * s)
      ..close();
    canvas.drawPath(gPath, whitePaint);

    paint.color = const Color(0xFFEA4335);
    final redBar = Path()
      ..moveTo(cx + 3.5 * s, cy - 2.5 * s)
      ..lineTo(cx + 8 * s, cy - 2.5 * s)
      ..lineTo(cx + 8 * s, cy + 0.5 * s)
      ..lineTo(cx + 3.5 * s, cy + 0.5 * s)
      ..close();
    canvas.drawPath(redBar, paint);

    paint.color = const Color(0xFF34A853);
    final greenBar = Path()
      ..moveTo(cx + 3.5 * s, cy + 2 * s)
      ..lineTo(cx + 8 * s, cy + 2 * s)
      ..lineTo(cx + 8 * s, cy + 5.5 * s)
      ..lineTo(cx + 3.5 * s, cy + 5.5 * s)
      ..close();
    canvas.drawPath(greenBar, paint);

    paint.color = const Color(0xFFFBBC05);
    final yellowBar = Path()
      ..moveTo(cx - 2 * s, cy + 0.5 * s)
      ..lineTo(cx + 1.5 * s, cy + 0.5 * s)
      ..lineTo(cx + 1.5 * s, cy + 5.5 * s)
      ..lineTo(cx - 2 * s, cy + 5.5 * s)
      ..close();
    canvas.drawPath(yellowBar, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
