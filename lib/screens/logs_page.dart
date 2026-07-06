import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/providers/vpn_provider.dart';
import 'package:WaledNet/theme_provider.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = Theme.of(context);

    // Auto-scroll when logs change
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0D0E11) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text(
          'سجلات التشخيص (Logs)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'نسخ الكل',
            onPressed: () {
              if (vpnProvider.vpnLogs.isEmpty) return;
              final allLogs = vpnProvider.vpnLogs.join('\n');
              Clipboard.setData(ClipboardData(text: allLogs)).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ كافة السجلات إلى الحافظة'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            tooltip: 'مسح السجلات',
            onPressed: () {
              vpnProvider.clearLogs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Auto Scroll Toggle Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: themeProvider.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عدد السطور: ${vpnProvider.vpnLogs.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'التمرير التلقائي',
                        style: TextStyle(
                          fontSize: 12,
                          color: _autoScroll ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                          fontWeight: _autoScroll ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _autoScroll ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        size: 14,
                        color: _autoScroll ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Console Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? const Color(0xFF050608) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: themeProvider.isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  width: 1.5,
                ),
              ),
              child: vpnProvider.vpnLogs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد سجلات حالياً...',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: vpnProvider.vpnLogs.length,
                      itemBuilder: (context, index) {
                        final logLine = vpnProvider.vpnLogs[index];
                        
                        // Parse log type for colored console styling
                        Color textColor = themeProvider.isDarkMode ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937);
                        if (logLine.contains('[Error]')) {
                          textColor = const Color(0xFFFF453A); // iOS Red
                        } else if (logLine.contains('[SSH]')) {
                          textColor = const Color(0xFF30D158); // iOS Green
                        } else if (logLine.contains('[System]')) {
                          textColor = const Color(0xFFBF5AF2); // iOS Purple
                        } else if (logLine.contains('WARN')) {
                          textColor = const Color(0xFFFF9F0A); // iOS Orange
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: SelectableText(
                            logLine,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12.5,
                              fontFamily: 'Courier', // Monospace font for logs
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
