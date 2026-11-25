import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';
import 'package:safir_admin/utils/permissions.dart';
import 'package:safir_admin/widgets/admin_ui.dart';
import 'package:safir_admin/widgets/users_data_list.dart';

class UserPage extends StatefulWidget {
  static const String id = 'webPageUsers';

  final String role;
  final Map<String, dynamic> permissions;

  const UserPage({
    super.key,
    this.role = 'superAdmin',
    this.permissions = const {},
  });

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | active | blocked

  late Future<_UserStats> _statsFuture = _loadStats();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canView => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: 'users',
        key: 'view',
      );

  /// شمارش سمت سرور (count) — به‌جای خواندن همهٔ کاربران.
  Future<_UserStats> _loadStats() async {
    final users = FirebaseFirestore.instance.collection('users');

    final total = await users.count().get();
    final blocked =
        await users.where('isBlocked', isEqualTo: true).count().get();

    final t = total.count ?? 0;
    final b = blocked.count ?? 0;

    return _UserStats(total: t, blocked: b);
  }

  void _refreshStats() {
    setState(() => _statsFuture = _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AdminStateMessage(
              icon: Icons.lock_outline_rounded,
              message: 'شما اجازهٔ مشاهدهٔ بخش مسافران را ندارید.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStats(),
                  const SizedBox(height: 20),
                  _buildTable(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.people_alt_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مسافران',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'فهرست مسافران ثبت‌شده، جستجو و مدیریت وضعیت حساب',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'به‌روزرسانی آمار',
          onPressed: _refreshStats,
          icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ───────── کارت‌های آمار (با عدد واقعی) ─────────

  Widget _buildStats() {
    return FutureBuilder<_UserStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final failed = snapshot.hasError;

        String value(int? n) {
          if (loading) return '…';
          if (failed || n == null) return '--';
          return AdminFormat.toFa(n);
        }

        final cards = [
          _StatData(
            title: 'کل مسافران',
            value: value(stats?.total),
            icon: Icons.groups_rounded,
            color: AppColors.info,
          ),
          _StatData(
            title: 'حساب فعال',
            value: value(stats?.active),
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.ok,
          ),
          _StatData(
            title: 'مسدود شده',
            value: value(stats?.blocked),
            icon: Icons.block_rounded,
            color: AppColors.danger,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == cards.length - 1 ? 0 : 10,
                      ),
                      child: _statCard(cards[i]),
                    ),
                ],
              );
            }

            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: _statCard(cards[i])),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(_StatData d) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.soft(d.color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d.icon, color: d.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  d.value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────── جدول ─────────

  Widget _buildTable() {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildControls(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(790.0, constraints.maxWidth);

              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        _buildTableHeader(),
                        const SizedBox(height: 8),
                        UsersDataList(
                          searchQuery: _query,
                          filterStatus: _filter,
                          role: widget.role,
                          permissions: widget.permissions,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final search = TextField(
      controller: _searchController,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      onChanged: (v) => setState(() => _query = v.trim()),
      decoration: InputDecoration(
        hintText: 'جستجو: نام، ایمیل، شماره تماس یا کد کاربر',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.brand),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'پاک کردن',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        isDense: true,
      ),
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip('all', 'همه'),
        _filterChip('active', 'فعال'),
        _filterChip('blocked', 'مسدود'),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 10), chips],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 14),
            chips,
          ],
        );
      },
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.brand : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    Widget cell(String title) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          cell('نام مسافر'),
          cell('ایمیل'),
          cell('شماره تماس'),
          cell('وضعیت حساب'),
        ],
      ),
    );
  }
}

class _UserStats {
  final int total;
  final int blocked;

  const _UserStats({required this.total, required this.blocked});

  int get active => total - blocked < 0 ? 0 : total - blocked;
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
