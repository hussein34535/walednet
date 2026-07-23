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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إحصائيات استخدام البيانات 📊'),
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
            colors: themeProvider.isDarkMode
                ? [
                    const Color(0xFF0F1018),
                    const Color(0xFF181926),
                  ]
                : [
                    const Color(0xFFF2F4F7),
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
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Today Summary Card
                      _buildTodayCard(theme, themeProvider),
                      const SizedBox(height: 24),

                      // Section Title
                      Row(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'سجل الاستخدام (آخر 30 يومًا)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Usage History List
                      if (_history.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            'لا يوجد سجل استخدام سابق حتى الآن',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      else
                        ..._history.map((usage) => _buildDayTile(usage, theme, themeProvider)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTodayCard(ThemeData theme, ThemeProvider themeProvider) {
    final usage = _today;
    final totalStr = _formatBytes(usage?.totalBytes ?? 0);
    final upStr = _formatBytes(usage?.uploadBytes ?? 0);
    final downStr = _formatBytes(usage?.downloadBytes ?? 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'استهلاك اليوم',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _today?.date ?? 'اليوم',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Total Bytes Large Text
              Text(
                totalStr,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),

              const Divider(height: 1),
              const SizedBox(height: 16),

              // Stats Row (Upload / Download / Sessions)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statColumn('⬆️ رفع البيانات', upStr, theme),
                  Container(
                    height: 30,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  _statColumn('⬇️ تنزيل البيانات', downStr, theme),
                  Container(
                    height: 30,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  _statColumn('🔗 عدد الجلسات', '${usage?.sessionCount ?? 0}', theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDayTile(DailyUsage usage, ThemeData theme, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.data_usage_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          usage.date,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '⬆️ ${_formatBytes(usage.uploadBytes)}  |  ⬇️ ${_formatBytes(usage.downloadBytes)}',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatBytes(usage.totalBytes),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
