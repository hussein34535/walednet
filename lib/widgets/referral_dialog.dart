import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vpn_provider.dart';
import '../services/referral_service.dart';

class ReferralDialog extends StatefulWidget {
  const ReferralDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ReferralDialog(),
    );
  }

  @override
  State<ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends State<ReferralDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isClaiming = false;
  String? _statusMessage;
  bool _isSuccess = false;

  static const _appleBlue = Color(0xFF007AFF);
  static const _appleGreen = Color(0xFF34C759);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    setState(() {
      _isClaiming = true;
      _statusMessage = 'جاري التحقق من أمان الجهاز...';
      _isSuccess = false;
    });

    final result = await ReferralService.claimReferralCode(
      uid: user?.uid ?? 'guest',
      referralCode: code,
    );

    if (!mounted) return;

    setState(() {
      _isClaiming = false;
      _statusMessage = result.message;
      _isSuccess = result.success;
    });

    if (result.success && result.bonusHours > 0) {
      final vpnProvider = Provider.of<VpnProvider>(context, listen: false);
      vpnProvider.activateReferralPremium(result.bonusHours);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final uidPart = (user?.uid ?? '89A2').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final myReferralCode = 'WALED-${uidPart.substring(0, uidPart.length >= 4 ? 4 : uidPart.length).toUpperCase()}';

    final bgCard = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final insetBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final borderColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: bgCard.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: SvgPicture.asset(
                          'assets/images/gift.svg',
                          colorFilter: const ColorFilter.mode(_appleGreen, BlendMode.srcIn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نظام الإحالة والجوائز',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'شهر بريميوم مجاناً (30 يومًا)',
                              style: TextStyle(
                                color: _appleBlue,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // My Referral Code Card (Apple Grouped Style)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: insetBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 0.6),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'كود الإحالة الخاص بك',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SelectableText(
                              myReferralCode,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                color: _appleBlue,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: myReferralCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ كود الإحالة بنجاح 📋'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              color: _appleBlue,
                              tooltip: 'نسخ',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Friend Code Input
                  Text(
                    'تفعيل كود صديق',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                    ],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الإحالة (WALED-XXXX)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0,
                        fontWeight: FontWeight.normal,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor: insetBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 0.6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 0.6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _appleBlue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hardware Security Badge
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        padding: const EdgeInsets.all(3),
                        child: SvgPicture.asset(
                          'assets/images/shield.svg',
                          colorFilter: ColorFilter.mode(
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'فحص العتاد المادي ضد التزوير والمحاكيات 🔒',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSuccess
                            ? _appleGreen.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? _appleGreen : Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isClaiming ? null : _handleClaim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _appleBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isClaiming
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'تفعيل الكود واستلام المكافأة',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
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
