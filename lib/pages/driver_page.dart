import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';
import 'package:safir_admin/utils/permissions.dart';
import 'package:safir_admin/widgets/admin_ui.dart';
import 'package:safir_admin/widgets/drivers_data_list.dart';

class DriverPage extends StatefulWidget {
  static const String id = 'webPageDrivers';

  final String role;
  final Map<String, dynamic> permissions;

  const DriverPage({
    super.key,
    this.role = 'superAdmin',
    this.permissions = const {},
  });

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverStats {
  final int total;
  final int approved; // تأییدشده و غیرمسدود
  final int blocked;

  const _DriverStats({
    required this.total,
    required this.approved,
    required this.blocked,
  });

  int get pending {
    final v = total - approved - blocked;
    return v < 0 ? 0 : v;
  }
}

class _DriverPageState extends State<DriverPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'all'; // all | pending | approved | blocked

  late Future<_DriverStats> _statsFuture = _loadStats();

  bool get _canView => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: 'drivers',
        key: 'view',
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// شمارش سمت سرور؛ وضعیت «مسدود» بر «تأییدشده» اولویت دارد (مثل لیست).
  Future<_DriverStats> _loadStats() async {
    final drivers = FirebaseFirestore.instance.collection('drivers');

    final total = (await drivers.count().get()).count ?? 0;
    final approvedAll = (await drivers
                .where('isApproved', isEqualTo: true)
                .count()
                .get())
            .count ??
        0;
    final blocked = (await drivers
                .where('isBlocked', isEqualTo: true)
                .count()
                .get())
            .count ??
        0;
    final both = (await drivers
                .where('isApproved', isEqualTo: true)
                .where('isBlocked', isEqualTo: true)
                .count()
                .get())
            .count ??
        0;

    return _DriverStats(
      total: total,
      approved: approvedAll - both,
      blocked: blocked,
    );
  }

  void _refreshStats() => setState(() => _statsFuture = _loadStats());

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
              message: 'دسترسی به بخش رانندگان ندارید.',
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
                  _buildSummaryCards(),
                  const SizedBox(height: 20),
                  _buildDriversTable(),
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
            Icons.local_taxi_rounded,
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
                'رانندگان',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'بررسی مدارک، تأیید و مدیریت وضعیت رانندگان',
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

  // ───────── کارت‌های آمار (کلیک = فیلتر) ─────────

  Widget _buildSummaryCards() {
    return FutureBuilder<_DriverStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final s = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final failed = snapshot.hasError;

        String v(int? n) {
          if (loading) return '…';
          if (failed || n == null) return '--';
          return AdminFormat.toFa(n);
        }

        final cards = [
          _SummaryData(
            filter: 'all',
            title: 'همه رانندگان',
            value: v(s?.total),
            icon: Icons.groups_rounded,
            color: AppColors.info,
          ),
          _SummaryData(
            filter: 'pending',
            title: 'در انتظار تأیید',
            value: v(s?.pending),
            icon: Icons.pending_actions_rounded,
            color: AppColors.warning,
          ),
          _SummaryData(
            filter: 'approved',
            title: 'تأیید شده',
            value: v(s?.approved),
            icon: Icons.verified_rounded,
            color: AppColors.ok,
          ),
          _SummaryData(
            filter: 'blocked',
            title: 'مسدود شده',
            value: v(s?.blocked),
            icon: Icons.block_rounded,
            color: AppColors.danger,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width < 620 ? 2 : 4;
            const gap = 12.0;
            final cardWidth = (width - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final c in cards)
                  SizedBox(width: cardWidth, child: _summaryCard(c)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _summaryCard(_SummaryData d) {
    final selected = _selectedFilter == d.filter;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedFilter = d.filter),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? d.color : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.soft(d.color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(d.icon, color: d.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
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
      ),
    );
  }

  // ───────── جستجو، فیلتر و جدول ─────────

  Widget _buildControls() {
    final search = TextField(
      controller: _searchController,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: 'جستجو: نام، شماره، ایمیل یا شناسهٔ راننده',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.brand),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'پاک کردن جستجو',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        isDense: true,
      ),
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('all', 'همه'),
        _chip('pending', 'در انتظار'),
        _chip('approved', 'تأیید شده'),
        _chip('blocked', 'مسدود'),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
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

  Widget _chip(String value, String label) {
    final selected = _selectedFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = value),
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

  Widget _buildDriversTable() {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildControls(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(980.0, constraints.maxWidth);

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
                        DriversDataList(
                          key: ValueKey(
                            '$_searchQuery-$_selectedFilter-${widget.role}',
                          ),
                          searchQuery: _searchQuery,
                          filterStatus: _selectedFilter,
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

  Widget _buildTableHeader() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _headerCell('کد', 8),
          _headerCell('نام راننده', 17),
          _headerCell('شماره تماس', 13),
          _headerCell('وسیلهٔ نقلیه', 16),
          _headerCell('وضعیت', 12),
          _headerCell('مدارک', 11),
          _headerCell('عملیات', 20),
        ],
      ),
    );
  }

  // flex دقیقاً مثل ردیف‌های DriversDataList تا ستون‌ها هم‌تراز بمانند
  Widget _headerCell(String title, int flex) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
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
  }
}

class _SummaryData {
  final String filter;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryData({
    required this.filter,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
