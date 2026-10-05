import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream =
      _firestore.collection('drivers').snapshots();

  static final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream =
      _firestore.collection('users').snapshots();

  // اپ راننده و مسافر سفرها را در rides ذخیره می‌کنند.
  static final Stream<QuerySnapshot<Map<String, dynamic>>> _ridesStream =
      _firestore.collection('rides').snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 28),
            _buildStatistics(),
            const SizedBox(height: 32),
            _buildMainContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'welcome_title'.tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'welcome_subtitle'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          // چون داده‌ها Stream هستند، صفحه خودکار آپدیت می‌شود.
          // این دکمه فقط برای حس Refresh در رابط کاربری باقی مانده است.
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text('refresh'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _driversStream,
      builder: (context, driversSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ridesStream,
              builder: (context, ridesSnapshot) {
                final String? error = _firstError(
                  driversSnapshot,
                  usersSnapshot,
                  ridesSnapshot,
                );

                if (error != null) {
                  return _buildErrorBox(error);
                }

                if (driversSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    usersSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    ridesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final int driversCount = driversSnapshot.data?.docs.length ?? 0;
                final int usersCount = usersSnapshot.data?.docs.length ?? 0;

                int activeTripsCount = 0;
                int completedTripsCount = 0;

                final rides = ridesSnapshot.data?.docs ?? [];

                for (final ride in rides) {
                  final String status =
                      ride.data()['status']?.toString() ?? '';

                  // وضعیت‌های واقعی استفاده‌شده در اپ:
                  // searching, accepted, arrived, onTrip, completed
                  if (status == 'searching' ||
                      status == 'accepted' ||
                      status == 'arrived' ||
                      status == 'onTrip') {
                    activeTripsCount++;
                  } else if (status == 'completed') {
                    completedTripsCount++;
                  }
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardWidth = constraints.maxWidth > 900
                        ? (constraints.maxWidth - 48) / 4
                        : (constraints.maxWidth - 16) / 2;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard(
                          width: cardWidth,
                          title: 'total_drivers'.tr(),
                          value: driversCount.toString(),
                          icon: Icons.badge_outlined,
                          color: AppColors.primary,
                        ),
                        _buildStatCard(
                          width: cardWidth,
                          title: 'active_trips'.tr(),
                          value: activeTripsCount.toString(),
                          icon: Icons.local_taxi_outlined,
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          width: cardWidth,
                          title: 'total_users'.tr(),
                          value: usersCount.toString(),
                          icon: Icons.people_outline,
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          width: cardWidth,
                          title: 'completed_trips'.tr(),
                          value: completedTripsCount.toString(),
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 800;

        final recentActivity = _buildRecentActivity();
        final systemStatus = _buildSystemStatus(context);

        if (isMobile) {
          return Column(
            children: [
              recentActivity,
              const SizedBox(height: 20),
              systemStatus,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: recentActivity),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: systemStatus),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recent_activity'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ridesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorText(snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                );
              }

              final rides = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                snapshot.data?.docs ?? [],
              );

              if (rides.isEmpty) {
                return _buildEmptyText('هنوز سفری ثبت نشده است');
              }

              rides.sort((a, b) {
                final Timestamp? aTime = _readTimestamp(a.data());
                final Timestamp? bTime = _readTimestamp(b.data());

                final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
                final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;

                return bMillis.compareTo(aMillis);
              });

              final latestRides = rides.take(10).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: latestRides.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 20, thickness: 0.5),
                itemBuilder: (context, index) {
                  final data = latestRides[index].data();
                  final String status = data['status']?.toString() ?? '';

                  return _buildActivityTile(
                    _rideTitle(status),
                    _rideSubtitle(data),
                    _formatTime(_readTimestamp(data)),
                    _statusColor(status),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'system_status'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'system_status_desc'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String? _firstError(
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

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: SelectableText(
        message,
        style: TextStyle(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorText(String message) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        'Firestore error:
$message',
        style: TextStyle(color: Colors.red.shade700),
      ),
    );
  }

  Widget _buildEmptyText(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(
    String title,
    String subtitle,
    String time,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          time,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Timestamp? _readTimestamp(Map<String, dynamic> data) {
    const keys = [
      'updatedat',
      'updatedAt',
      'createdat',
      'createdAt',
      'completedat',
      'completedAt',
      'startedat',
      'startedAt',
      'arrivedat',
      'arrivedAt',
    ];

    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value;
      }
    }

    return null;
  }

  String _rideTitle(String status) {
    switch (status) {
      case 'searching':
        return 'درخواست سفر جدید';
      case 'accepted':
        return 'سفر توسط راننده پذیرفته شد';
      case 'arrived':
        return 'راننده به مبدأ رسید';
      case 'onTrip':
        return 'سفر در حال انجام است';
      case 'completed':
        return 'سفر تکمیل شد';
      case 'cancelledByDriver':
        return 'سفر توسط راننده لغو شد';
      case 'cancelledByUser':
        return 'سفر توسط مسافر لغو شد';
      default:
        return 'به‌روزرسانی سفر';
    }
  }

  String _rideSubtitle(Map<String, dynamic> data) {
    final String passengerName =
        data['passengername']?.toString() ??
        data['passengerName']?.toString() ??
        data['userName']?.toString() ??
        data['fullname']?.toString() ??
        'مسافر';

    final String driverName =
        data['drivername']?.toString() ??
        data['driverName']?.toString() ??
        '';

    final String origin =
        data['originaddress']?.toString() ??
        data['originAddress']?.toString() ??
        data['pickupaddress']?.toString() ??
        '';

    final String destination =
        data['destinationaddress']?.toString() ??
        data['destinationAddress']?.toString() ??
        data['dropoffaddress']?.toString() ??
        '';

    final List<String> parts = [
      passengerName,
      if (driverName.isNotEmpty) 'راننده: $driverName',
      if (origin.isNotEmpty) origin,
      if (destination.isNotEmpty) 'به $destination',
    ];

    return parts.join(' • ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelledByDriver':
      case 'cancelledByUser':
        return Colors.red;
      case 'onTrip':
        return Colors.blue;
      case 'arrived':
        return Colors.deepPurple;
      case 'accepted':
        return Colors.orange;
      case 'searching':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final DateTime date = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(date);

    if (difference.inMinutes < 1) {
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
