import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ridesStream;

  @override
  void initState() {
    super.initState();
    _createStreams();
  }

  void _createStreams() {
    _driversStream = _firestore.collection('drivers').snapshots();
    _usersStream = _firestore.collection('users').snapshots();
    _ridesStream = _firestore.collection('rides').snapshots();
  }

  void _refreshDashboard() {
    setState(() {
      _createStreams();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 24),
                _buildDashboardData(isMobile),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderText(),
                const SizedBox(height: 18),
                _buildRefreshButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildHeaderText()),
                _buildRefreshButton(),
              ],
            ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'welcome_title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'welcome_subtitle'.tr(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: _refreshDashboard,
      icon: const Icon(Icons.refresh_rounded, size: 19),
      label: Text('refresh'.tr()),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildDashboardData(bool isMobile) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _driversStream,
      builder: (context, driversSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ridesStream,
              builder: (context, ridesSnapshot) {
                final error = _getFirstError(
                  driversSnapshot,
                  usersSnapshot,
                  ridesSnapshot,
                );

                if (error != null) {
                  return _buildErrorPanel(error);
                }

                final isLoading =
                    driversSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    usersSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    ridesSnapshot.connectionState ==
                        ConnectionState.waiting;

                if (isLoading) {
                  return _buildLoadingPanel();
                }

                final drivers =
                    driversSnapshot.data?.docs ?? <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

                final users =
                    usersSnapshot.data?.docs ?? <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

                final rides =
                    ridesSnapshot.data?.docs ?? <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

                final stats = _calculateStats(rides);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(
                      driversCount: drivers.length,
                      usersCount: users.length,
                      activeTrips: stats.active,
                      completedTrips: stats.completed,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 26),
                    _buildContentGrid(
                      rides: rides,
                      stats: stats,
                      isMobile: isMobile,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsGrid({
    required int driversCount,
    required int usersCount,
    required int activeTrips,
    required int completedTrips,
    required bool isMobile,
  }) {
    final cards = [
      _StatData(
        title: 'total_drivers'.tr(),
        value: driversCount.toString(),
        icon: Icons.local_taxi_rounded,
        color: const Color(0xFF5B5FEF),
        subtitle: 'راننده ثبت‌شده',
      ),
      _StatData(
        title: 'total_users'.tr(),
        value: usersCount.toString(),
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF159DCE),
        subtitle: 'مسافر ثبت‌شده',
      ),
      _StatData(
        title: 'active_trips'.tr(),
        value: activeTrips.toString(),
        icon: Icons.navigation_rounded,
        color: const Color(0xFFF59E0B),
        subtitle: 'سفر در جریان',
      ),
      _StatData(
        title: 'completed_trips'.tr(),
        value: completedTrips.toString(),
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF16A36A),
        subtitle: 'سفر تکمیل‌شده',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 620) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i + 2 < cards.length ? 14 : 0,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildStatCard(cards[i])),
                      if (i + 1 < cards.length) ...[
                        const SizedBox(width: 14),
                        Expanded(child: _buildStatCard(cards[i + 1])),
                      ],
                    ],
                  ),
                ),
            ],
          );
        }

        final cardWidth = (width - 42) / 4;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(card),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: 24,
                ),
              ),
              Icon(
                Icons.more_horiz_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> rides,
    required _RideStats stats,
    required bool isMobile,
  }) {
    final activityCard = _buildRecentRides(rides);
    final summaryCard = _buildTripSummary(stats);

    if (isMobile) {
      return Column(
        children: [
          activityCard,
          const SizedBox(height: 18),
          summaryCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: activityCard),
        const SizedBox(width: 18),
        Expanded(flex: 2, child: summaryCard),
      ],
    );
  }

  Widget _buildRecentRides(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rides,
  ) {
    final sortedRides = [...rides];

    sortedRides.sort((a, b) {
      final aTime = _readTimestamp(a.data());
      final bTime = _readTimestamp(b.data());

      return (bTime?.millisecondsSinceEpoch ?? 0)
          .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
    });

    final latestRides = sortedRides.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.history_rounded,
            title: 'فعالیت‌های اخیر',
            subtitle: 'آخرین سفرهای ثبت‌شده در سیستم',
          ),
          const SizedBox(height: 18),
          if (latestRides.isEmpty)
            _buildEmptyState(
              icon: Icons.local_taxi_outlined,
              message: 'هنوز سفری ثبت نشده است',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: latestRides.length,
              separatorBuilder: (_, __) => Divider(
                height: 22,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final data = latestRides[index].data();
                final status = _normalizeStatus(
                  data['status']?.toString() ?? '',
                );

                return _buildRideItem(
                  title: _rideTitle(status),
                  subtitle: _rideSubtitle(data),
                  status: _statusLabel(status),
                  color: _statusColor(status),
                  time: _formatTime(_readTimestamp(data)),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTripSummary(_RideStats stats) {
    final total = stats.total == 0 ? 1 : stats.total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.analytics_outlined,
            title: 'خلاصه سفرها',
            subtitle: 'وضعیت فعلی سفرهای سیستم',
          ),
          const SizedBox(height: 22),
          _buildProgressRow(
            title: 'در حال انجام',
            value: stats.active,
            total: total,
            color: Colors.orange,
          ),
          const SizedBox(height: 18),
          _buildProgressRow(
            title: 'تکمیل‌شده',
            value: stats.completed,
            total: total,
            color: Colors.green,
          ),
          const SizedBox(height: 18),
          _buildProgressRow(
            title: 'لغوشده',
            value: stats.cancelled,
            total: total,
            color: Colors.red,
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اطلاعات به‌صورت زنده از Firebase دریافت می‌شود',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String title,
    required int value,
    required int total,
    required Color color,
  }) {
    final percentage = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideItem({
    required String title,
    required String subtitle,
    required String status,
    required Color color,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.local_taxi_rounded,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
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

  Widget _buildLoadingPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(50),
      decoration: _cardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildErrorPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(
            icon,
            size: 44,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.grey.shade100,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  _RideStats _calculateStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rides,
  ) {
    int active = 0;
    int completed = 0;
    int cancelled = 0;

    for (final ride in rides) {
      final status = _normalizeStatus(
        ride.data()['status']?.toString() ?? '',
      );

      if (_isActiveTrip(status)) {
        active++;
      } else if (status == 'completed') {
        completed++;
      } else if (_isCancelledTrip(status)) {
        cancelled++;
      }
    }

    return _RideStats(
      total: rides.length,
      active: active,
      completed: completed,
      cancelled: cancelled,
    );
  }

  String? _getFirstError(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> drivers,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> users,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> rides,
  ) {
    if (drivers.hasError) {
      return 'خطا در خواندن راننده‌ها:
${drivers.error}';
    }

    if (users.hasError) {
      return 'خطا در خواندن مسافرها:
${users.error}';
    }

    if (rides.hasError) {
      return 'خطا در خواندن سفرها:
${rides.error}';
    }

    return null;
  }

  String _normalizeStatus(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  bool _isActiveTrip(String status) {
    return status == 'searching' ||
        status == 'accepted' ||
        status == 'arrived' ||
        status == 'ontrip' ||
        status == 'on_trip';
  }

  bool _isCancelledTrip(String status) {
    return status == 'cancelled' ||
        status == 'cancelled_by_driver' ||
        status == 'cancelled_by_passenger' ||
        status == 'cancelled_by_user' ||
        status == 'cancelledbydriver' ||
        status == 'cancelledbypassenger' ||
        status == 'cancelledbyuser';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'searching':
        return 'در انتظار راننده';
      case 'accepted':
        return 'پذیرفته‌شده';
      case 'arrived':
        return 'راننده رسیده';
      case 'ontrip':
      case 'on_trip':
        return 'در حال انجام';
      case 'completed':
        return 'تکمیل‌شده';
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelledbydriver':
        return 'لغوشده توسط راننده';
      case 'cancelled_by_passenger':
      case 'cancelled_by_user':
      case 'cancelledbypassenger':
      case 'cancelledbyuser':
        return 'لغوشده توسط مسافر';
      default:
        return 'نامشخص';
    }
  }

  String _rideTitle(String status) {
    switch (status) {
      case 'searching':
        return 'درخواست سفر جدید';
      case 'accepted':
        return 'سفر پذیرفته شد';
      case 'arrived':
        return 'راننده به مبدأ رسید';
      case 'ontrip':
      case 'on_trip':
        return 'سفر در حال انجام';
      case 'completed':
        return 'سفر تکمیل شد';
      default:
        return 'به‌روزرسانی سفر';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'searching':
        return Colors.amber.shade800;
      case 'accepted':
        return Colors.orange;
      case 'arrived':
        return Colors.deepPurple;
      case 'ontrip':
      case 'on_trip':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelled_by_passenger':
      case 'cancelled_by_user':
      case 'cancelledbydriver':
      case 'cancelledbypassenger':
      case 'cancelledbyuser':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _rideSubtitle(Map<String, dynamic> data) {
    final passengerName = _readString(
          data,
          [
            'passengername',
            'passengerName',
            'userName',
            'username',
            'fullname',
            'fullName',
          ],
        ) ??
        'مسافر';

    final driverName = _readString(
      data,
      [
        'drivername',
        'driverName',
        'drivername',
      ],
    );

    final origin = _readAddress(
      data,
      [
        'originaddress',
        'originAddress',
        'pickupaddress',
        'pickupAddress',
        'origin',
        'pickup',
      ],
    );

    final destination = _readAddress(
      data,
      [
        'destinationaddress',
        'destinationAddress',
        'dropoffaddress',
        'dropoffAddress',
        'destination',
        'dropoff',
      ],
    );

    final parts = <String>[
      passengerName,
      if (driverName != null && driverName.isNotEmpty)
        'راننده: $driverName',
      if (origin != null && origin.isNotEmpty) origin,
      if (destination != null && destination.isNotEmpty)
        'به $destination',
    ];

    return parts.join(' • ');
  }

  String? _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is Map) {
        final nested = value['address'] ?? value['name'] ?? value['title'];

        if (nested != null && nested.toString().trim().isNotEmpty) {
          return nested.toString().trim();
        }
      }
    }

    return null;
  }

  String? _readAddress(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    return _readString(data, keys);
  }

  Timestamp? _readTimestamp(Map<String, dynamic> data) {
    const keys = [
      'updatedAt',
      'updatedat',
      'createdAt',
      'createdat',
      'completedAt',
      'completedat',
      'startedAt',
      'startedat',
      'arrivedAt',
      'arrivedat',
      'timestamp',
      'time',
    ];

    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value;
      }

      if (value is DateTime) {
        return Timestamp.fromDate(value);
      }
    }

    return null;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final difference = DateTime.now().difference(date);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'همین حالا';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} ساعت پیش';
    }

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}

class _RideStats {
  final int total;
  final int active;
  final int completed;
  final int cancelled;

  const _RideStats({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
  });
}
