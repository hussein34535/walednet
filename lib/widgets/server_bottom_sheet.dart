import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/theme_provider.dart';

class ServerBottomSheet extends StatelessWidget {
  final List<VpnServer> servers;
  final VpnServer? selectedServer;
  final Map<String, int> serverDelays;
  final ValueChanged<VpnServer> onServerSelected;

  const ServerBottomSheet({
    super.key,
    required this.servers,
    required this.selectedServer,
    required this.serverDelays,
    required this.onServerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(32),
        ),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // iOS Style Drag Handle
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'اختر السيرفر المناسب',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                final isSelected = selectedServer == server;
                final delay = serverDelays[server.url];

                Color delayColor;
                String delayText;
                if (delay == null) {
                  delayText = '...';
                  delayColor = Colors.grey;
                } else if (delay == -1 || delay == 0) {
                  delayText = 'Offline';
                  delayColor = const Color(0xFFFF3B30); // iOS Red
                } else {
                  delayText = '${delay}ms';
                  if (delay < 150) {
                    delayColor = const Color(0xFF34C759); // iOS Green
                  } else if (delay < 300) {
                    delayColor = const Color(0xFFFF9500); // iOS Orange
                  } else {
                    delayColor = const Color(0xFFFF3B30); // iOS Red
                  }
                }

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.08)
                        : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.4)
                          : themeProvider.isDarkMode
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.03),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      onTap: () {
                        Navigator.pop(context);
                        onServerSelected(server);
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.dns_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        server.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: delayColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              delayText,
                              style: TextStyle(
                                color: delayColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
