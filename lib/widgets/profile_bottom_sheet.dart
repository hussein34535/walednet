import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/theme_provider.dart';

class ProfileBottomSheet extends StatelessWidget {
  final List<SniProfile> profiles;
  final SniProfile? selectedProfile;
  final ValueChanged<SniProfile> onProfileSelected;

  const ProfileBottomSheet({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.onProfileSelected,
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
            'اختر الحزمة (SNI Profile)',
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
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isSelected = selectedProfile == profile;

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
                        onProfileSelected(profile);
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        profile.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        profile.sni.isEmpty ? 'حزمة افتراضية' : profile.sni,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            )
                          : null,
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
