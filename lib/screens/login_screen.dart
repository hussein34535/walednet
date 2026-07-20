import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _isLogin = true;
  bool _obscurePassword = true;

  late AnimationController _entranceController;
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _shakeController;

  late Animation<double> _logoScale;
  late Animation<double> _bgAnim;
  late Animation<double> _shakeAnim;

  late Animation<double> _fadeLogo;
  late Animation<double> _fadeTitle;
  late Animation<double> _fadeSubtitle;
  late Animation<double> _fadeSocial;
  late Animation<double> _fadeDivider;
  late Animation<double> _fadeForm;
  late Animation<double> _fadeButton;
  late Animation<double> _fadeFooter;

  late Animation<Offset> _slideLogo;
  late Animation<Offset> _slideTitle;
  late Animation<Offset> _slideSubtitle;
  late Animation<Offset> _slideSocial;
  late Animation<Offset> _slideDivider;
  late Animation<Offset> _slideForm;
  late Animation<Offset> _slideButton;
  late Animation<Offset> _slideFooter;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _fadeLogo = _buildFade(0.0, 0.3);
    _fadeTitle = _buildFade(0.1, 0.4);
    _fadeSubtitle = _buildFade(0.2, 0.5);
    _fadeSocial = _buildFade(0.3, 0.6);
    _fadeDivider = _buildFade(0.4, 0.7);
    _fadeForm = _buildFade(0.5, 0.8);
    _fadeButton = _buildFade(0.6, 0.9);
    _fadeFooter = _buildFade(0.7, 1.0);

    _slideLogo = _buildSlide(0.0, 0.3);
    _slideTitle = _buildSlide(0.1, 0.4);
    _slideSubtitle = _buildSlide(0.2, 0.5);
    _slideSocial = _buildSlide(0.3, 0.6);
    _slideDivider = _buildSlide(0.4, 0.7);
    _slideForm = _buildSlide(0.5, 0.8);
    _slideButton = _buildSlide(0.6, 0.9);
    _slideFooter = _buildSlide(0.7, 1.0);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entranceController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoggedIn) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  Animation<double> _buildFade(double start, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  Animation<Offset> _buildSlide(double start, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bgController.dispose();
    _logoController.dispose();
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _haptic(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.error:
        HapticFeedback.vibrate();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.themeData;
    final isDark = themeProvider.isDarkMode;
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: const Color(0xFF07090E),
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: const Color(0xFFF8FAFC),
            ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            _buildAnimatedBackground(isDark),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final shake = sin(_shakeAnim.value * 3.14159 * 4) * 8 * (1 - _shakeAnim.value);
                    return Transform.translate(
                      offset: Offset(shake, 0),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.06),
                      _buildLogo(isDark),
                      SizedBox(height: size.height * 0.025),
                      _buildTitle(theme, isDark),
                      SizedBox(height: size.height * 0.01),
                      _buildSubtitle(theme, isDark),
                      SizedBox(height: size.height * 0.045),
                      if (auth.errorMessage != null)
                        _buildError(auth.errorMessage!, isDark),
                      _buildForm(theme, isDark),
                      SizedBox(height: size.height * 0.02),
                      if (_isLogin) _buildForgotPassword(theme, isDark),
                      SizedBox(height: size.height * 0.025),
                      _buildSubmitButton(theme, isDark, auth),
                      SizedBox(height: size.height * 0.025),
                      _buildDivider(theme, isDark),
                      SizedBox(height: size.height * 0.025),
                      _buildGoogleButton(theme, isDark, auth),
                      SizedBox(height: size.height * 0.02),
                      _buildToggle(theme, isDark),
                      SizedBox(height: size.height * 0.04),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _bgAnim,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: _AmbientGradientPainter(
              progress: _bgAnim.value,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo(bool isDark) {
    return FadeTransition(
      opacity: _fadeLogo,
      child: SlideTransition(
        position: _slideLogo,
        child: AnimatedBuilder(
          animation: _logoScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _logoScale.value,
              child: child,
            );
          },
          child: SizedBox(
            width: 120,
            height: 120,
            child: ClipRect(
              child: Transform.scale(
                scale: 2.2,
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeTitle,
      child: SlideTransition(
        position: _slideTitle,
        child: Text(
          'WaledNet',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeSubtitle,
      child: SlideTransition(
        position: _slideSubtitle,
        child: Text(
          _isLogin
              ? 'اتصال آمن. خصوصية كاملة. سرعة فائقة.'
              : 'أنشئ حسابك وابدأ رحلتك الآمنة.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: isDark
                ? Colors.white.withOpacity(0.45)
                : const Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(ThemeData theme, bool isDark, AuthProvider auth) {
    return FadeTransition(
      opacity: _fadeSocial,
      child: SlideTransition(
        position: _slideSocial,
        child: _SocialButton(
          icon: _buildGoogleIcon(),
          label: 'المتابعة بحساب جوجل',
          isDark: isDark,
          isLoading: auth.isLoading,
          onTap: () {
            _haptic(HapticFeedbackType.light);
            _handleGoogleSignIn(auth);
          },
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/images/google.svg',
      width: 22,
      height: 22,
    );
  }

  Widget _buildDivider(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeDivider,
      child: SlideTransition(
        position: _slideDivider,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeForm,
      child: SlideTransition(
        position: _slideForm,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _isLogin
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          _buildInput(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            label: 'الاسم',
                            hint: 'أدخل اسمك الكامل',
                            icon: Icons.person_outline_rounded,
                            isDark: isDark,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'يرجى إدخال الاسم'
                                : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
              ),
              _buildInput(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'البريد الإلكتروني',
                hint: 'example@email.com',
                icon: Icons.mail_outline_rounded,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'يرجى إدخال البريد الإلكتروني';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'بريد إلكتروني غير صالح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildInput(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: 'كلمة المرور',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                obscureText: _obscurePassword,
                suffixIcon: GestureDetector(
                  onTap: () {
                    _haptic(HapticFeedbackType.light);
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: isDark
                          ? Colors.white.withOpacity(0.3)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? 'كلمة المرور 6 أحرف على الأقل'
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withOpacity(0.6)
                : const Color(0xFF475569),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFFCBD5E1),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 20,
                color: isDark
                    ? Colors.white.withOpacity(0.35)
                    : const Color(0xFF94A3B8),
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF1F5F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF0A84FF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 2,
              ),
            ),
            errorStyle: const TextStyle(
              fontSize: 12,
              fontFamily: 'Cairo',
              color: Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeForm,
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => _haptic(HapticFeedbackType.light),
          child: Text(
            'نسيت كلمة المرور؟',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0A84FF).withOpacity(0.8),
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme, bool isDark, AuthProvider auth) {
    return FadeTransition(
      opacity: _fadeButton,
      child: SlideTransition(
        position: _slideButton,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: auth.isLoading
                ? null
                : () {
                    _haptic(HapticFeedbackType.medium);
                    _isLogin
                        ? _handleLogin(auth)
                        : _handleRegister(auth);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              disabledBackgroundColor: const Color(0xFF0A84FF).withOpacity(0.4),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: const Color(0xFF0A84FF).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeFooter,
      child: SlideTransition(
        position: _slideFooter,
        child: GestureDetector(
          onTap: () {
            _haptic(HapticFeedbackType.light);
            setState(() => _isLogin = !_isLogin);
          },
          child: Text.rich(
            TextSpan(
              text: _isLogin
                  ? 'ليس لديك حساب؟ '
                  : 'لديك حساب بالفعل؟ ',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.4)
                    : const Color(0xFF94A3B8),
                fontFamily: 'Cairo',
              ),
              children: [
                TextSpan(
                  text: _isLogin ? 'أنشئ حساب' : 'سجّل الدخول',
                  style: const TextStyle(
                    color: Color(0xFF0A84FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      _haptic(HapticFeedbackType.error);
      return;
    }
    final success = await auth.signInWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      _haptic(HapticFeedbackType.heavy);
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _shakeController.forward(from: 0);
      _haptic(HapticFeedbackType.error);
    }
  }

  Future<void> _handleRegister(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      _haptic(HapticFeedbackType.error);
      return;
    }
    final success = await auth.registerWithEmail(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
    );
    if (success && mounted) {
      _haptic(HapticFeedbackType.heavy);
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _shakeController.forward(from: 0);
      _haptic(HapticFeedbackType.error);
    }
  }

  Future<void> _handleGoogleSignIn(AuthProvider auth) async {
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      _haptic(HapticFeedbackType.heavy);
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _shakeController.forward(from: 0);
      _haptic(HapticFeedbackType.error);
    }
  }
}

class _SocialButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _pressScale.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: widget.isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? Colors.white.withOpacity(0.9)
                      : const Color(0xFF1E293B),
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientGradientPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AmbientGradientPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDark) return;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0A84FF).withOpacity(0.08 + progress * 0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * (0.75 + progress * 0.1),
            size.height * (0.15 - progress * 0.05),
          ),
          radius: size.width * 0.6,
        ),
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withOpacity(0.06 + (1 - progress) * 0.03),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * (0.2 - progress * 0.08),
            size.height * (0.85 + progress * 0.05),
          ),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withOpacity(0.04 + progress * 0.02),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.5,
            size.height * (0.45 + progress * 0.1),
          ),
          radius: size.width * 0.4,
        ),
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant _AmbientGradientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

enum HapticFeedbackType { light, medium, heavy, error }
