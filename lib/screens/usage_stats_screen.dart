import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/daily_usage.dart';
import '../services/usage_tracker_service.dart';
import '../theme_provider.dart';

class UsageStatsScreen extends StatefulWidget {
  const UsageStatsScreen({super.key});

  @override
  State<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

class _UsageStatsScreenState extends State<UsageStatsScreen> {
  List<DailyUsage> _history = [];
  DailyUsage? _today;
  bool _loading = true;

  static const _appleBlue = Color(0xFF007AFF);
  static const _appleOrange = Color(0xFFFF9500);
  static const _appleIndigo = Color(0xFF5856D6);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = UsageTrackerService();
    final today = await service.getTodayUsage();
    final history = await service.getUsageHistory(days: 30);
    if (!mounted) return;
    setState(() {
      _today = today;
      _history = history;
      _loading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'إحصائيات الاستخدام',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Today Apple Card
                    _buildTodayAppleCard(theme, isDark),
                    const SizedBox(height: 22),

                    // Section Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'سجل الاستخدام (آخر 30 يومًا)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // List of Usage History (Apple Inset Grouped Container)
                    if (_history.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          'لا يوجد سجل استهلاك بيانات سابق حتى الآن',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            width: 0.6,
                          ),
                        ),
                        child: Column(
                          children: _history.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final usage = entry.value;
                            final isLast = idx == _history.length - 1;
                            return _buildAppleDayTile(usage, theme, isDark, isLast);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTodayAppleCard(ThemeData theme, bool isDark) {
    final usage = _today;
    final totalBytes = usage?.totalBytes ?? 0;
    final upBytes = usage?.uploadBytes ?? 0;
    final downBytes = usage?.downloadBytes ?? 0;

    final totalStr = _formatBytes(totalBytes);
    final upStr = _formatBytes(upBytes);
    final downStr = _formatBytes(downBytes);

    final double downRatio = totalBytes > 0 ? (downBytes / totalBytes).clamp(0.05, 0.95) : 0.5;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _appleBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/analytics.svg',
                      colorFilter: const ColorFilter.mode(_appleBlue, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'استهلاك اليوم',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _appleBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _today?.date ?? 'اليوم',
                  style: const TextStyle(
                    color: _appleBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Total Number
          Center(
            child: Column(
              children: [
                Text(
                  totalStr,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'إجمالي حركة البيانات اليوم',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (downRatio * 100).toInt(),
                    child: Container(color: _appleBlue),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((1.0 - downRatio) * 100).toInt(),
                    child: Container(color: _appleOrange),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricPillar('⬇️ التنزيل', downStr, _appleBlue, theme),
              Container(height: 24, width: 0.6, color: borderColor),
              _metricPillar('⬆️ الرفع', upStr, _appleOrange, theme),
              Container(height: 24, width: 0.6, color: borderColor),
              _metricPillar('🔗 الجلسات', '${usage?.sessionCount ?? 0}', _appleIndigo, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPillar(String label, String value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAppleDayTile(DailyUsage usage, ThemeData theme, bool isDark, bool isLast) {
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _appleBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  'assets/images/analytics.svg',
                  colorFilter: const ColorFilter.mode(_appleBlue, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usage.date,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '⬇️ ${_formatBytes(usage.downloadBytes)}',
                          style: const TextStyle(fontSize: 11.5, color: _appleBlue),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '⬆️ ${_formatBytes(usage.uploadBytes)}',
                          style: const TextStyle(fontSize: 11.5, color: _appleOrange),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _formatBytes(usage.totalBytes),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: _appleBlue,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.6,
            indent: 56,
            color: borderColor,
          ),
      ],
    );
  }
}
