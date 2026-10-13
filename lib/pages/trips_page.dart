import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class TripsPage extends StatefulWidget {
  static const String id = 'webPageTrips';

  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> _tripsStream =
      FirebaseFirestore.instance.collection('rides').snapshots();

  String _searchQuery = '';
  String _selectedFilter = 'all';

  final TextEditingController _searchController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _tripsStream,
          builder: (context, snapshot) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 760;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile),
                      const SizedBox(height: 22),
                      _buildTopCards(snapshot, isMobile),
                      const SizedBox(height: 22),
                      _buildFilters(isMobile),
                      const SizedBox(height: 18),
                      _buildTripsContent(
                        snapshot: snapshot,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.20),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.alt_route_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'active_rides'.tr(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'مدیریت و مشاهده تمام سفرهای سفیر',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return content;
    }

    return Row(
      children: [
        Expanded(child: content),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Icon(
                Icons.sync_rounded,
                color: Colors.green.shade600,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                'به‌روزرسانی زنده',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopCards(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    bool isMobile,
  ) {
    final documents = snapshot.data?.docs ?? [];

    final stats = _calculateStats(documents);

    final cards = [
      _TripCardData(
        title: 'همه سفرها',
        value: stats.total.toString(),
        icon: Icons.route_rounded,
        color: const Color(0xFF5B5FEF),
      ),
      _TripCardData(
        title: 'در حال انجام',
        value: stats.active.toString(),
        icon: Icons.navigation_rounded,
        color: Colors.orange,
      ),
      _TripCardData(
        title: 'تکمیل‌شده',
        value: stats.completed.toString(),
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      ),
      _TripCardData(
        title: 'لغوشده',
        value: stats.cancelled.toString(),
        icon: Icons.cancel_rounded,
        color: Colors.red,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              return _buildTripCard(cards[index]);
            },
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _buildTripCard(cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTripCard(_TripCardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              data.icon,
              color: data.color,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: TextStyle(
                    color: data.color,
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

  Widget _buildFilters(bool isMobile) {
    final searchField = TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'جستجو بر اساس مسافر، راننده، مبدأ یا مقصد...',
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primary,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'پاک کردن',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.3,
          ),
        ),
      ),
    );

    final filterField = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedFilter = value;
            });
          },
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text('همه سفرها'),
            ),
            DropdownMenuItem(
              value: 'searching',
              child: Text('در انتظار راننده'),
            ),
            DropdownMenuItem(
              value: 'active',
              child: Text('در حال انجام'),
            ),
            DropdownMenuItem(
              value: 'completed',
              child: Text('تکمیل‌شده'),
            ),
            DropdownMenuItem(
              value: 'cancelled',
              child: Text('لغوشده'),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterTitle(),
                const SizedBox(height: 14),
                searchField,
                const SizedBox(height: 12),
                filterField,
              ],
            )
          : Row(
              children: [
                _buildFilterTitle(),
                const SizedBox(width: 22),
                Expanded(child: searchField),
                const SizedBox(width: 14),
                SizedBox(
                  width: 220,
                  child: filterField,
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: AppColors.primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'جستجو و فیلتر',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTripsContent({
    required AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    required bool isMobile,
  }) {
    if (snapshot.hasError) {
      return _buildStateMessage(
        icon: Icons.error_outline_rounded,
        message: 'خطا در دریافت اطلاعات سفرها:
${snapshot.error}',
        color: Colors.red.shade600,
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingState();
    }

    final documents = snapshot.data?.docs ?? [];
    final filteredDocuments = documents.where(_matchesTrip).toList();

    if (documents.isEmpty) {
      return _buildStateMessage(
        icon: Icons.route_outlined,
        message: 'هیچ سفری یافت نشد',
        color: Colors.grey.shade500,
      );
    }

    if (filteredDocuments.isEmpty) {
      return _buildStateMessage(
        icon: Icons.search_off_rounded,
        message: 'نتیجه‌ای با این مشخصات یافت نشد',
        color: Colors.grey.shade500,
      );
    }

    filteredDocuments.sort((a, b) {
      final aTime = _readTimestamp(a.data());
      final bTime = _readTimestamp(b.data());

      return (bTime?.millisecondsSinceEpoch ?? 0)
          .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
    });

    if (isMobile) {
      return _buildMobileTripList(filteredDocuments);
    }

    return _buildDesktopTable(filteredDocuments);
  }

  Widget _buildDesktopTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.table_rows_rounded,
            title: 'فهرست سفرها',
            subtitle: 'آخرین سفرهای ثبت‌شده در سیستم',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1020,
                child: Column(
                  children: [
                    _buildTableHeader(),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: documents.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        return _buildDesktopTripRow(documents[index]);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.82),
          ],
        ),
      ),
      child: Row(
        children: [
          _headerCell('کد سفر', 8),
          _headerCell('مسافر', 14),
          _headerCell('راننده', 14),
          _headerCell('مبدأ', 19),
          _headerCell('مقصد', 19),
          _headerCell('کرایه', 11),
          _headerCell('وضعیت', 15),
        ],
      ),
    );
  }

  Widget _headerCell(String title, int flex) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTripRow(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final trip = document.data();
    final item = _parseTrip(document.id, trip);

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _dataCell(
            flex: 8,
            child: _buildTripCode(item.id),
          ),
          _dataCell(
            flex: 14,
            child: _buildPersonCell(
              item.passengerName,
              Icons.person_outline_rounded,
            ),
          ),
          _dataCell(
            flex: 14,
            child: _buildPersonCell(
              item.driverName,
              Icons.local_taxi_outlined,
            ),
          ),
          _dataCell(
            flex: 19,
            child: _buildAddressCell(
              item.origin,
              Icons.trip_origin_rounded,
            ),
          ),
          _dataCell(
            flex: 19,
            child: _buildAddressCell(
              item.destination,
              Icons.location_on_outlined,
            ),
          ),
          _dataCell(
            flex: 11,
            child: _buildFare(item.fare),
          ),
          _dataCell(
            flex: 15,
            child: _buildStatusChip(item.status),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTripList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return Column(
      children: documents.map((document) {
        final item = _parseTrip(
          document.id,
          document.data(),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildMobileTripCard(item),
        );
      }).toList(),
    );
  }

  Widget _buildMobileTripCard(_TripItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTripCode(item.id),
              const Spacer(),
              _buildStatusChip(item.status),
            ],
          ),
          const SizedBox(height: 16),
          _buildMobileInfoRow(
            icon: Icons.person_outline_rounded,
            title: 'مسافر',
            value: item.passengerName,
          ),
          const SizedBox(height: 10),
          _buildMobileInfoRow(
            icon: Icons.local_taxi_outlined,
            title: 'راننده',
            value: item.driverName,
          ),
          const SizedBox(height: 10),
          _buildMobileInfoRow(
            icon: Icons.trip_origin_rounded,
            title: 'مبدأ',
            value: item.origin,
          ),
          const SizedBox(height: 10),
          _buildMobileInfoRow(
            icon: Icons.location_on_outlined,
            title: 'مقصد',
            value: item.destination,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: Colors.grey.shade500,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'کرایه',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _buildFare(item.fare),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 19,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 55,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dataCell({
    required int flex,
    required Widget child,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: child,
      ),
    );
  }

  Widget _buildTripCode(String id) {
    final shortId = id.length > 6 ? id.substring(0, 6) : id;

    return Tooltip(
      message: id,
      child: Text(
        shortId,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPersonCell(String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey.shade500,
          size: 17,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCell(String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 16,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFare(String fare) {
    return Text(
      '$fare افغانی',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatusChip(String rawStatus) {
    final status = _normalizeStatus(rawStatus);
    final color = _statusColor(status);
    final label = _statusLabel(status);
    final icon = _statusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesTrip(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final item = _parseTrip(
      document.id,
      document.data(),
    );

    final query = _searchQuery.trim().toLowerCase();

    final matchesSearch = query.isEmpty ||
        item.id.toLowerCase().contains(query) ||
        item.passengerName.toLowerCase().contains(query) ||
        item.driverName.toLowerCase().contains(query) ||
        item.origin.toLowerCase().contains(query) ||
        item.destination.toLowerCase().contains(query);

    final status = _normalizeStatus(item.status);
    bool matchesFilter = true;

    switch (_selectedFilter) {
      case 'searching':
        matchesFilter = status == 'searching';
        break;
      case 'active':
        matchesFilter = _isActiveStatus(status);
        break;
      case 'completed':
        matchesFilter =
            status == 'completed' || status == 'ended';
        break;
      case 'cancelled':
        matchesFilter = _isCancelledStatus(status);
        break;
      case 'all':
      default:
        matchesFilter = true;
    }

    return matchesSearch && matchesFilter;
  }

  _TripItem _parseTrip(
    String id,
    Map<String, dynamic> data,
  ) {
    final driverId = _readText(
      data,
      [
        'driver_id',
        'driverId',
      ],
    );

    var driverName = _readText(
      data,
      [
        'driver_name',
        'driverName',
        'drivername',
      ],
    );

    if (driverName.isEmpty) {
      driverName = driverId == 'waiting'
          ? 'در انتظار راننده'
          : 'تخصیص‌نیافته';
    }

    final passengerName = _readText(
      data,
      [
        'passenger_name',
        'passengerName',
        'passengername',
        'userName',
        'username',
        'user_name',
      ],
      fallback: 'نامشخص',
    );

    final origin = _readAddress(
      data,
      [
        'originAddress',
        'origin_address',
        'originaddress',
        'pickup_address',
        'pickupAddress',
        'origin',
      ],
      fallback: '-',
    );

    final destination = _readAddress(
      data,
      [
        'destinationAddress',
        'destination_address',
        'destinationaddress',
        'dropoff_address',
        'dropoffAddress',
        'destination',
      ],
      fallback: '-',
    );

    final fare = _readText(
      data,
      [
        'fareAmount',
        'fare_amount',
        'fare',
        'price',
        'amount',
      ],
      fallback: '0',
    );

    final status = _readText(
      data,
      ['status'],
      fallback: 'searching',
    );

    return _TripItem(
      id: id,
      passengerName: passengerName,
      driverName: driverName,
      origin: origin,
      destination: destination,
      fare: fare,
      status: status,
    );
  }

  String _readAddress(
    Map<String, dynamic> data,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is Map) {
        final nested = _readMapText(
          value,
          [
            'address',
            'name',
            'title',
            'formattedAddress',
          ],
        );

        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }

    return fallback;
  }

  String _readText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString();
      }

      if (value is Map) {
        final nested = _readMapText(
          value,
          [
            'name',
            'title',
            'value',
            'text',
          ],
        );

        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }

    return fallback;
  }

  String _readMapText(
    Map<dynamic, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
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
      'timestamp',
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

  _TripStats _calculateStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    int active = 0;
    int completed = 0;
    int cancelled = 0;

    for (final document in documents) {
      final status = _normalizeStatus(
        _readText(
          document.data(),
          ['status'],
          fallback: 'searching',
        ),
      );

      if (_isActiveStatus(status)) {
        active++;
      } else if (status == 'completed' || status == 'ended') {
        completed++;
      } else if (_isCancelledStatus(status)) {
        cancelled++;
      }
    }

    return _TripStats(
      total: documents.length,
      active: active,
      completed: completed,
      cancelled: cancelled,
    );
  }

  String _normalizeStatus(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  bool _isActiveStatus(String status) {
    return status == 'searching' ||
        status == 'accepted' ||
        status == 'arrived' ||
        status == 'ontrip' ||
        status == 'on_trip';
  }

  bool _isCancelledStatus(String status) {
    return status == 'cancelled' ||
        status == 'cancelled_by_driver' ||
        status == 'cancelledbydriver' ||
        status == 'cancelled_by_passenger' ||
        status == 'cancelledbypassenger' ||
        status == 'cancelled_by_user' ||
        status == 'cancelledbyuser';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'searching':
        return Colors.orange.shade800;
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.deepPurple;
      case 'ontrip':
      case 'on_trip':
        return Colors.indigo;
      case 'completed':
      case 'ended':
        return Colors.green;
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelledbydriver':
      case 'cancelled_by_passenger':
      case 'cancelledbypassenger':
      case 'cancelled_by_user':
      case 'cancelledbyuser':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'searching':
        return 'در انتظار راننده';
      case 'accepted':
        return 'پذیرفته‌شده';
      case 'arrived':
        return 'راننده در مبدأ';
      case 'ontrip':
      case 'on_trip':
        return 'در حال سفر';
      case 'completed':
      case 'ended':
        return 'پایان‌یافته';
      case 'cancelled':
        return 'لغوشده';
      case 'cancelled_by_driver':
      case 'cancelledbydriver':
        return 'لغو توسط راننده';
      case 'cancelled_by_passenger':
      case 'cancelledbypassenger':
      case 'cancelled_by_user':
      case 'cancelledbyuser':
        return 'لغو توسط مسافر';
      default:
        return status.isEmpty ? 'نامشخص' : status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'searching':
        return Icons.search_rounded;
      case 'accepted':
        return Icons.thumb_up_alt_outlined;
      case 'arrived':
        return Icons.place_outlined;
      case 'ontrip':
      case 'on_trip':
        return Icons.navigation_rounded;
      case 'completed':
      case 'ended':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 21,
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

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: _cardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(34),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: 13),
          SelectableText(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.5,
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
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _TripItem {
  final String id;
  final String passengerName;
  final String driverName;
  final String origin;
  final String destination;
  final String fare;
  final String status;

  const _TripItem({
    required this.id,
    required this.passengerName,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.fare,
    required this.status,
  });
}

class _TripStats {
  final int total;
  final int active;
  final int completed;
  final int cancelled;

  const _TripStats({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
  });
}

class _TripCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _TripCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
