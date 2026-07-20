import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:WaledNet/services/api_service.dart';
import 'package:WaledNet/providers/vpn_provider.dart';

class ProfileBottomSheet extends StatefulWidget {
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
  State<ProfileBottomSheet> createState() => _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends State<ProfileBottomSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    final selected = widget.selectedProfile;
    if (selected == null) return;
    final index = widget.profiles.indexOf(selected);
    if (index < 0) return;
    final offset = index * 80.0;
    if (offset > _scrollController.position.maxScrollExtent) return;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddSniDialog(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vpnProvider = Provider.of<VpnProvider>(context, listen: false);
    
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: themeProvider.isDarkMode
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04),
                ),
              ),
              title: const Text(
                'إضافة SNI جديد',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'اسم الحزمة (مثال: رفع وي)',
                        hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey.withOpacity(0.7),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسم الحزمة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: hostController,
                      textAlign: TextAlign.left,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Host / Domain (مثال: scorm.ekb.eg)',
                        hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey.withOpacity(0.7),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال النطاق (Domain)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey.withOpacity(0.8),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isLoading = true;
                            });
                            
                            final success = await ApiService.addSniProfile(
                              nameController.text.trim(),
                              hostController.text.trim(),
                            );
                            
                            if (success) {
                              await vpnProvider.refreshData();
                              if (context.mounted) {
                                Navigator.pop(context); // Close dialog
                                Navigator.pop(context); // Close bottom sheet to show updated list
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تمت إضافة الـ SNI الجديد بنجاح!',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isLoading = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'فشل في إضافة الـ SNI. يرجى المحاولة لاحقاً.',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
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
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'اختر الحزمة (SNI Profile)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddSniDialog(context),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    'إضافة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.profiles.length,
              itemBuilder: (context, index) {
                final profile = widget.profiles[index];
                final isSelected = widget.selectedProfile?.sni == profile.sni;

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
                        widget.onProfileSelected(profile);
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
                        profile.displayName,
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
    ),
  ),
);
  }
}
