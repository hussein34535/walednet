import 'dart:ui';
import 'package:flutter/material.dart';
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

  static const _brandA = Color(0xFF4834D4);
  static const _brandB = Color(0xFF6C5CE7);
  static const _cyan = Color(0xFF007AFF);
  static const _orange = Color(0xFFFF9500);

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إحصائيات الاستخدام 📊'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0C0D14),
                    const Color(0xFF161726),
                  ]
                : [
                    const Color(0xFFF2F4F8),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Today Hero Dashboard Card
                      _buildTodayHeroCard(theme, isDark),
                      const SizedBox(height: 24),

                      // Section Title Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _brandA.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: _brandB,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'سجل الاستخدام اليومي (آخر 30 يومًا)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // List of Usage History
                      if (_history.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.data_usage_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لا يوجد سجل استهلاك بيانات سابق حتى الآن',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._history.map((usage) => _buildDayTile(usage, theme, isDark)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTodayHeroCard(ThemeData theme, bool isDark) {
    final usage = _today;
    final totalBytes = usage?.totalBytes ?? 0;
    final upBytes = usage?.uploadBytes ?? 0;
    final downBytes = usage?.downloadBytes ?? 0;

    final totalStr = _formatBytes(totalBytes);
    final upStr = _formatBytes(upBytes);
    final downStr = _formatBytes(downBytes);

    final double downRatio = totalBytes > 0 ? (downBytes / totalBytes).clamp(0.05, 0.95) : 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _brandA.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Label & Date Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_brandA, _brandB]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'استهلاك اليوم',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _brandA.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _brandB.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _today?.date ?? 'اليوم',
                      style: const TextStyle(
                        color: _brandB,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Total Bytes Main Number Display
              Center(
                child: Column(
                  children: [
                    Text(
                      totalStr,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: _cyan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي الحركة التراكمية اليوم',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Download / Upload Visual Bar Meter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (downRatio * 100).toInt(),
                            child: Container(color: _cyan),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            flex: ((1.0 - downRatio) * 100).toInt(),
                            child: Container(color: _orange),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3 Metric Stat Pillars (Download, Upload, Sessions)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricPillar('⬇️ التنزيل', downStr, _cyan, theme),
                  Container(height: 32, width: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
                  _metricPillar('⬆️ الرفع', upStr, _orange, theme),
                  Container(height: 32, width: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
                  _metricPillar('🔗 الجلسات', '${usage?.sessionCount ?? 0}', _brandB, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricPillar(String label, String value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDayTile(DailyUsage usage, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brandA.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: _brandB,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usage.date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '⬇️ ${_formatBytes(usage.downloadBytes)}',
                        style: const TextStyle(fontSize: 12, color: _cyan, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '⬆️ ${_formatBytes(usage.uploadBytes)}',
                        style: const TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cyan.withValues(alpha: 0.25)),
              ),
              child: Text(
                _formatBytes(usage.totalBytes),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: _cyan,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
