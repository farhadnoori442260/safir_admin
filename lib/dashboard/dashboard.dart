import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';
import 'package:safir_admin/utils/permissions.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

const List<String> _activeStatuses = [
  'searching',
  'accepted',
  'arrived',
  'ontrip',
];
const List<String> _completedStatuses = ['completed', 'ended'];
const List<String> _cancelledStatuses = [
  'cancelled_by_passenger',
  'cancelled_by_driver',
  'cancelled',
];

/// آمار داشبورد؛ هر مقدار null یعنی خواندنش ناموفق بود (نمایش «--»).
class _Stats {
  final int? drivers;
  final int? approvedDrivers;
  final int? users;
  final int? activeTrips;
  final int? completedToday;
  final int? cancelledToday;

  const _Stats({
    this.drivers,
    this.approvedDrivers,
    this.users,
    this.activeTrips,
    this.completedToday,
    this.cancelledToday,
  });

  int? get pendingDrivers {
    if (drivers == null || approvedDrivers == null) return null;
    final v = drivers! - approvedDrivers!;
    return v < 0 ? 0 : v;
  }
}

class Dashboard extends StatefulWidget {
  final String role;
  final Map<String, dynamic> permissions;

  const Dashboard({
    super.key,
    required this.role,
    this.permissions = const {},
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late Future<_Stats> _statsFuture;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _recentStream;

  bool _can(String section) => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: section,
        key: 'view',
      );

  bool get _canDrivers => _can('drivers');
  bool get _canUsers => _can('users');
  bool get _canTrips => _can('trips');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _statsFuture = _loadStats();

    // فقط ۸ سفر آخر (به‌جای کل کالکشن)
    _recentStream = _canTrips
        ? _db
            .collection('rides')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .snapshots()
        : null;
  }

  void _refresh() => setState(_reload);

  // ───────── شمارش‌ها (سمت سرور با count) ─────────

  Future<int?> _count(Query<Map<String, dynamic>> query) async {
    try {
      final snap = await query.count().get();
      return snap.count;
    } catch (_) {
      return null;
    }
  }

  Future<_Stats> _loadStats() async {
    final now = DateTime.now();
    final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    final drivers = _db.collection('drivers');
    final rides = _db.collection('rides');

    final results = await Future.wait<int?>([
      _canDrivers ? _count(drivers) : Future.value(null),
      _canDrivers
          ? _count(drivers.where('isApproved', isEqualTo: true))
          : Future.value(null),
      _canUsers ? _count(_db.collection('users')) : Future.value(null),
      _canTrips
          ? _count(rides.where('status', whereIn: _activeStatuses))
          : Future.value(null),
      _canTrips
          ? _count(
              rides
                  .where('status', whereIn: _completedStatuses)
                  .where('createdAt', isGreaterThanOrEqualTo: todayStart),
            )
          : Future.value(null),
      _canTrips
          ? _count(
              rides
                  .where('status', whereIn: _cancelledStatuses)
                  .where('createdAt', isGreaterThanOrEqualTo: todayStart),
            )
          : Future.value(null),
    ]);

    return _Stats(
      drivers: results[0],
      approvedDrivers: results[1],
      users: results[2],
      activeTrips: results[3],
      completedToday: results[4],
      cancelledToday: results[5],
    );
  }

  // ───────── رابط کاربری ─────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                if (!_canDrivers && !_canUsers && !_canTrips)
                  _buildRoleMessage()
                else
                  _buildBody(isMobile),
              ],
            ),
          );
        },
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
            Icons.dashboard_rounded,
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
                'داشبورد',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'نمای کلی سفیر؛ آمار امروز و آخرین سفرها',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, size: 19),
          label: const Text('به‌روزرسانی'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isMobile) {
    return FutureBuilder<_Stats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final stats = snapshot.data ?? const _Stats();

        String v(int? n) {
          if (loading) return '…';
          return n == null ? '--' : AdminFormat.toFa(n);
        }

        final cards = <_StatData>[
          if (_canDrivers)
            _StatData(
              title: 'رانندگان',
              value: v(stats.drivers),
              subtitle: loading || stats.pendingDrivers == null
                  ? 'راننده ثبت‌شده'
                  : '${AdminFormat.toFa(stats.pendingDrivers!)} در انتظار تأیید',
              icon: Icons.local_taxi_rounded,
              color: AppColors.info,
              highlight: (stats.pendingDrivers ?? 0) > 0,
            ),
          if (_canUsers)
            _StatData(
              title: 'مسافران',
              value: v(stats.users),
              subtitle: 'مسافر ثبت‌شده',
              icon: Icons.people_alt_rounded,
              color: AppColors.brand,
            ),
          if (_canTrips)
            _StatData(
              title: 'سفرهای در جریان',
              value: v(stats.activeTrips),
              subtitle: 'همین حالا',
              icon: Icons.navigation_rounded,
              color: AppColors.warning,
            ),
          if (_canTrips)
            _StatData(
              title: 'تکمیل‌شدهٔ امروز',
              value: v(stats.completedToday),
              subtitle: 'سفر تکمیل‌شده',
              icon: Icons.check_circle_rounded,
              color: AppColors.ok,
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(cards),
            if (_canTrips) ...[
              const SizedBox(height: 22),
              _buildContentGrid(stats, loading, isMobile),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(List<_StatData> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 620 ? 2 : (cards.length >= 4 ? 4 : cards.length);
        const gap = 12.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(width: cardWidth, child: _buildStatCard(c)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(_StatData d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d.highlight ? d.color.withOpacity(0.55) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.soft(d.color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d.icon, color: d.color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            d.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            d.value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            d.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: d.highlight ? d.color : AppColors.textMuted,
              fontSize: 12,
              fontWeight: d.highlight ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid(_Stats stats, bool loading, bool isMobile) {
    final recent = _buildRecentRides();
    final summary = _buildTripSummary(stats, loading);

    if (isMobile) {
      return Column(children: [recent, const SizedBox(height: 16), summary]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: recent),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: summary),
      ],
    );
  }

  Widget _buildRecentRides() {
    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.history_rounded,
            title: 'آخرین سفرها',
            subtitle: '۸ سفر اخیر ثبت‌شده در سیستم (زنده)',
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _recentStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AdminStateMessage(
                  icon: Icons.error_outline_rounded,
                  message: 'خطا در خواندن سفرها:\n${snapshot.error}',
                  color: AppColors.danger,
                );
              }
              if (!snapshot.hasData) return const AdminLoading();

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'هنوز سفری ثبت نشده است',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 22, color: AppColors.border),
                itemBuilder: (context, i) => _rideItem(docs[i].data()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _rideItem(Map<String, dynamic> data) {
    final status = _normalize(data['status']?.toString() ?? '');
    final color = _statusColor(status);
    final date = AdminFormat.readDate(data['createdAt'] ?? data['created_at']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.soft(color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.local_taxi_rounded, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _rideSubtitle(data),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  AdminChip(
                    label: _statusLabel(status, data),
                    icon: Icons.circle,
                    color: color,
                  ),
                  if (date != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _timeAgo(date),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripSummary(_Stats stats, bool loading) {
    final active = stats.activeTrips ?? 0;
    final done = stats.completedToday ?? 0;
    final cancelled = stats.cancelledToday ?? 0;
    final total = active + done + cancelled;

    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.analytics_outlined,
            title: 'خلاصهٔ سفرها',
            subtitle: 'در جریان و امروز',
          ),
          const SizedBox(height: 20),
          _progressRow('در جریان', stats.activeTrips, active, total,
              AppColors.warning, loading),
          const SizedBox(height: 16),
          _progressRow('تکمیل‌شدهٔ امروز', stats.completedToday, done, total,
              AppColors.ok, loading),
          const SizedBox(height: 16),
          _progressRow('لغوشدهٔ امروز', stats.cancelledToday, cancelled, total,
              AppColors.danger, loading),
        ],
      ),
    );
  }

  Widget _progressRow(
    String title,
    int? raw,
    int value,
    int total,
    Color color,
    bool loading,
  ) {
    final pct = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              loading ? '…' : (raw == null ? '--' : AdminFormat.toFa(raw)),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.soft(color),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.brand, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleMessage() {
    String title;
    String message;
    IconData icon;

    switch (widget.role) {
      case 'support':
        title = 'داشبورد پشتیبانی';
        message = 'برای مدیریت درخواست‌ها از بخش پشتیبانی استفاده کنید.';
        icon = Icons.support_agent_rounded;
        break;
      case 'finance':
        title = 'داشبورد مالی';
        message = 'برای مدیریت کمیسیون و کرایه‌ها از منوی مالی استفاده کنید.';
        icon = Icons.account_balance_wallet_rounded;
        break;
      default:
        title = 'داشبورد';
        message = 'برای این حساب هنوز آماری تعیین نشده است.';
        icon = Icons.dashboard_rounded;
    }

    return AdminCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppColors.brand),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ───────── کمکی‌ها ─────────

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  String _statusLabel(String status, Map<String, dynamic> data) {
    switch (status) {
      case 'searching':
        return 'در انتظار راننده';
      case 'accepted':
        return 'پذیرفته‌شده';
      case 'arrived':
        return 'راننده رسیده';
      case 'ontrip':
      case 'on_trip':
        return 'در حال سفر';
      case 'completed':
      case 'ended':
        return 'تکمیل‌شده';
      case 'cancelled_by_driver':
        return 'لغو توسط راننده';
      case 'cancelled_by_passenger':
        return 'لغو توسط مسافر';
      case 'cancelled':
        return data['cancelled_by']?.toString().toLowerCase() == 'admin'
            ? 'لغو توسط ادمین'
            : 'لغوشده';
      default:
        return 'نامشخص';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'searching':
        return AppColors.warning;
      case 'accepted':
      case 'arrived':
        return AppColors.info;
      case 'ontrip':
      case 'on_trip':
        return AppColors.brand;
      case 'completed':
      case 'ended':
        return AppColors.ok;
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelled_by_passenger':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  String _rideSubtitle(Map<String, dynamic> data) {
    final passenger = _readString(data, const [
          'passenger_name',
          'passengername',
          'passengerName',
          'userName',
          'username',
        ]) ??
        'مسافر';
    final driver =
        _readString(data, const ['driver_name', 'drivername', 'driverName']);
    final origin = _readString(data, const [
      'originAddress',
      'origin_address',
      'originaddress',
      'pickupAddress',
      'origin',
    ]);
    final destination = _readString(data, const [
      'destinationAddress',
      'destination_address',
      'destinationaddress',
      'dropoffAddress',
      'destination',
    ]);

    return [
      passenger,
      if (driver != null) 'راننده: $driver',
      if (origin != null) origin,
      if (destination != null) 'به $destination',
    ].join(' • ');
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) return value.trim();

      if (value is Map) {
        final nested = value['address'] ?? value['name'] ?? value['title'];
        if (nested != null && nested.toString().trim().isNotEmpty) {
          return nested.toString().trim();
        }
      }
    }
    return null;
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.isNegative || diff.inMinutes < 1) return 'همین حالا';
    if (diff.inHours < 1) {
      return '${AdminFormat.toFa(diff.inMinutes)} دقیقه پیش';
    }
    if (diff.inDays < 1) {
      return '${AdminFormat.toFa(diff.inHours)} ساعت پیش';
    }
    return AdminFormat.jalaliDate(date);
  }
}

class _StatData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.highlight = false,
  });
}
