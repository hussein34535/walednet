import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      _statusMessage = 'جاري التحقق من أمان وعتاد الجهاز...';
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final uidPart = (user?.uid ?? '89A2').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final myReferralCode = 'WALED-${uidPart.substring(0, uidPart.length >= 4 ? 4 : uidPart.length).toUpperCase()}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      elevation: 16,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نظام الإحالة والمكافآت',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'احصل على شهر كامل بريميوم (30 يومًا) مجاناً 🎁',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // User's Code Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'كود الدعوة الخاص بك',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        myReferralCode,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: myReferralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ كود الإحالة بنجاح!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'نسخ الكود',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Claim Code Section
            Text(
              'إدخال كود صديق',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldVal, newVal) => TextEditingValue(
                    text: newVal.text.toUpperCase(),
                    selection: newVal.selection,
                  ),
                ),
              ],
              decoration: InputDecoration(
                hintText: 'أدخل كود الإحالة هنا',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Hardware Protection Badge
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'محمي بنظام فحص العتاد المادي ضد المحاكيات والاستنساخ 🔒',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status message feedback
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isSuccess
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isSuccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            ElevatedButton(
              onPressed: _isClaiming ? null : _handleClaim,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isClaiming
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'تفعيل الكود والحصول على المكافأة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
