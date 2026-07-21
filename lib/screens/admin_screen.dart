import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:WaledNet/models/user_model.dart';
import 'package:WaledNet/providers/auth_provider.dart';
import 'package:WaledNet/services/admin_service.dart';
import 'package:WaledNet/theme/app_colors.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _searchCtrl = TextEditingController();
  final _admin = AdminService();
  List<UserModel> _users = [];
  List<UserModel> _recent = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _searching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initAdmin();
  }

  Future<void> _initAdmin() async {
    if (!_admin.adminChecked) {
      await _admin.checkAdminStatus();
    }
    if (!_admin.isAdmin && mounted) {
      Navigator.of(context).pop();
      return;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final recent = await _admin.getRecentUsers();
    final stats = await _admin.getStats();
    if (mounted) {
      setState(() {
        _recent = recent;
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _doSearch(String query) async {
    setState(() => _searchQuery = query);
    if (query.trim().isEmpty) {
      setState(() {
        _users = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await _admin.searchUsers(query);
    if (mounted) {
      setState(() {
        _users = results;
        _searching = false;
      });
    }
  }

  Future<void> _togglePremium(UserModel user) async {
    final newVal = !user.isPremium;
    final email = context.read<AuthProvider>().email;
    final ok = await _admin.togglePremium(user.uid, newVal, email);
    if (ok && mounted) {
      setState(() {
        _users = _users.map((u) => u.uid == user.uid ? u.copyWith(isPremium: newVal) : u).toList();
        _recent = _recent.map((u) => u.uid == user.uid ? u.copyWith(isPremium: newVal) : u).toList();
      });
      _loadData();
    }
  }

  Future<void> _toggleBan(UserModel user) async {
    final newVal = !user.isBanned;
    final ok = await _admin.toggleBan(user.uid, newVal);
    if (ok && mounted) {
      setState(() {
        _users = _users.map((u) => u.uid == user.uid ? u.copyWith(isBanned: newVal) : u).toList();
        _recent = _recent.map((u) => u.uid == user.uid ? u.copyWith(isBanned: newVal) : u).toList();
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
    final ink = isDark ? Colors.white : AppColors.textPrimaryLight;
    final muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final showing = _searchQuery.isEmpty ? _recent : _users;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07090E) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _buildTopBar(card, border, ink),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 8),
                      _buildSearchBar(card, border, ink, muted),
                      const SizedBox(height: 16),
                      if (_searchQuery.isEmpty) ...[
                        _buildStatsRow(card, border, ink, muted),
                        const SizedBox(height: 20),
                        _buildSectionLabel('آخر المستخدمين', muted),
                        const SizedBox(height: 8),
                      ],
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (showing.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text(
                              _searchQuery.isEmpty ? 'لا يوجد مستخدمين' : 'لا توجد نتائج',
                              style: TextStyle(color: muted, fontSize: 15),
                            ),
                          ),
                        )
                      else
                        ...showing.map((u) => _buildUserCard(u, card, border, ink, muted)),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color card, Color border, Color ink) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Material(
            color: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(width: 40, height: 40, child: Icon(Icons.arrow_back_rounded, size: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Text('لوحة التحكم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ink),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color card, Color border, Color ink, Color muted) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _doSearch,
        style: TextStyle(color: ink, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم أو الإيميل...',
          hintStyle: TextStyle(color: muted, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: muted, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: muted, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _doSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Color card, Color border, Color ink, Color muted) {
    return Row(
      children: [
        _buildStatCard('المستخدمين', _stats['total'] ?? 0, AppColors.primary, card, border),
        const SizedBox(width: 10),
        _buildStatCard('بريميوم', _stats['premium'] ?? 0, const Color(0xFFF6C453), card, border),
        const SizedBox(width: 10),
        _buildStatCard('محظور', _stats['banned'] ?? 0, const Color(0xFFFF3B30), card, border),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color, Color card, Color border) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted)),
    );
  }

  Widget _buildUserCard(UserModel user, Color card, Color border, Color ink, Color muted) {
    final initial = user.displayName.isNotEmpty ? user.displayName.trim().substring(0, 1) : user.email.substring(0, 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: user.isPremium
                      ? const LinearGradient(colors: [Color(0xFFF6C453), Color(0xFFE8A33D)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(initial.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : 'مستخدم',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(user.email, style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildToggleRow(
                  label: 'بريميوم',
                  value: user.isPremium,
                  activeColor: const Color(0xFFF6C453),
                  onChanged: (_) => _togglePremium(user),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToggleRow(
                  label: 'محظور',
                  value: user.isBanned,
                  activeColor: const Color(0xFFFF3B30),
                  onChanged: (_) => _toggleBan(user),
                ),
              ),
            ],
          ),
          if (user.isPremium && user.premiumActivatedAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 13, color: muted),
                const SizedBox(width: 4),
                Text(
                  _formatDate(user.premiumActivatedAt!),
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                if (user.premiumActivatedBy != null) ...[
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(width: 8),
                  Icon(Icons.person_rounded, size: 13, color: muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      user.premiumActivatedBy!,
                      style: TextStyle(fontSize: 11, color: muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? activeColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: value ? activeColor : Colors.grey),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value ? activeColor : Colors.grey)),
          const Spacer(),
          SizedBox(
            height: 26,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: activeColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
