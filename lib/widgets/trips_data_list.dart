import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

class TripsDataList extends StatefulWidget {
  final String searchQuery;

  const TripsDataList({super.key, this.searchQuery = ''});

  @override
  State<TripsDataList> createState() => _TripsDataListState();
}

class _TripsDataListState extends State<TripsDataList> {
  // فقط سفرهای تمام‌شده، حداکثر ۲۰۰ مورد (به‌جای خواندن کل کالکشن).
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = FirebaseFirestore
      .instance
      .collection('rides')
      .where('status', whereIn: const ['completed', 'ended', 'finished'])
      .limit(200)
      .snapshots();

  bool _isOpeningMap = false;

  static const _dateKeys = [
    'completedAt',
    'completed_at',
    'endedAt',
    'ended_at',
    'updatedAt',
    'updated_at',
    'publishDateTime',
    'time',
    'createdAt',
    'created_at',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminStateMessage(
            icon: Icons.error_outline_rounded,
            message: 'خطا در خواندن سفرها:\n${snapshot.error}',
            color: AppColors.danger,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminLoading();
        }

        final docs = (snapshot.data?.docs ?? []).toList();
        if (docs.isEmpty) {
          return const AdminStateMessage(
            icon: Icons.route_outlined,
            message: 'هنوز سفر تکمیل‌شده‌ای ثبت نشده است',
          );
        }

        docs.sort((a, b) {
          final x = _timestamp(a.data())?.millisecondsSinceEpoch ?? 0;
          final y = _timestamp(b.data())?.millisecondsSinceEpoch ?? 0;
          return y.compareTo(x);
        });

        final trips = docs
            .map((d) => _parse(d.id, d.data()))
            .where(_matches)
            .toList();

        if (trips.isEmpty) {
          return const AdminStateMessage(
            icon: Icons.search_off_rounded,
            message: 'نتیجه‌ای با این مشخصات یافت نشد',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: trips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _row(context, trips[i]),
        );
      },
    );
  }

  bool _matches(_Trip t) {
    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.id.toLowerCase().contains(q) ||
        t.passenger.toLowerCase().contains(q) ||
        t.driver.toLowerCase().contains(q) ||
        t.car.toLowerCase().contains(q);
  }

  Widget _row(BuildContext context, _Trip t) {
    return AdminCard(
      minHeight: 76,
      child: Row(
        children: [
          _cell(20, _code(t.id)),
          _cell(15, _iconText(t.passenger, Icons.person_outline_rounded)),
          _cell(15, _iconText(t.driver, Icons.local_taxi_outlined)),
          _cell(15, _iconText(t.car, Icons.directions_car_outlined)),
          _cell(16, _iconText(t.dateText, Icons.schedule_rounded)),
          _cell(12, _fare(t.fare)),
          _cell(18, _mapButton(context, t)),
        ],
      ),
    );
  }

  Widget _cell(int flex, Widget child) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: child,
        ),
      );

  Widget _code(String id) {
    final short = id.length > 8 ? id.substring(0, 8) : id;
    return Tooltip(
      message: id,
      child: Text(
        short,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.brand,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _iconText(String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 17),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _fare(String fare) {
    return Text(
      '${_money(fare)} افغانی',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _mapButton(BuildContext context, _Trip t) {
    final enabled = t.hasCoordinates;
    final color = enabled ? AppColors.brand : AppColors.textMuted;

    return Tooltip(
      message: enabled ? 'نمایش مسیر روی نقشه' : 'مختصات مسیر ثبت نشده است',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !enabled || _isOpeningMap ? null : () => _openMap(context, t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? AppColors.brandSoft : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isOpeningMap
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : Icon(Icons.map_outlined, size: 17, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  enabled ? 'مشاهده مسیر' : 'بدون مختصات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context, _Trip t) async {
    if (!t.hasCoordinates) {
      showAdminSnack(context, 'مختصات مبدأ یا مقصد این سفر کامل نیست.',
          tone: AdminTone.warning);
      return;
    }

    setState(() => _isOpeningMap = true);

    final uri = Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': '${t.pLat},${t.pLng};${t.dLat},${t.dLng}',
    });

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAdminSnack(context, 'بازکردن نقشه امکان‌پذیر نیست.',
            tone: AdminTone.error);
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در بازکردن نقشه: $e',
            tone: AdminTone.error);
      }
    } finally {
      if (mounted) setState(() => _isOpeningMap = false);
    }
  }

  // ───────── تجزیهٔ سفر ─────────
  _Trip _parse(String docId, Map<String, dynamic> d) {
    final p = _point(d['pickUpLatLng'] ??
        d['pickupLatLng'] ??
        d['pickupLocation'] ??
        d['originLocation']);
    final o = _point(d['dropOffLatLng'] ??
        d['dropoffLatLng'] ??
        d['dropoffLocation'] ??
        d['destinationLocation']);

    return _Trip(
      id: _text(d, const ['tripID', 'tripId', 'trip_id'], fallback: docId),
      passenger: _text(
        d,
        const [
          'passenger_name',
          'passengerName',
          'passengername',
          'userName',
          'username',
          'user_name',
          'name',
        ],
        fallback: 'نامشخص',
      ),
      driver: _text(
        d,
        const ['driver_name', 'driverName', 'drivername'],
        fallback: 'نامشخص',
      ),
      car: _car(d),
      fare: _text(
        d,
        const ['fareAmount', 'fare_amount', 'fare', 'price', 'amount'],
        fallback: '0',
      ),
      dateText: _formatDate(_value(d, _dateKeys)),
      pLat: _num(d, const [
            'pickUpLat',
            'pickupLat',
            'pickupLatitude',
            'originLat',
            'originLatitude',
          ]) ??
          (p == null ? null : p[0]),
      pLng: _num(d, const [
            'pickUpLng',
            'pickupLng',
            'pickupLongitude',
            'originLng',
            'originLongitude',
          ]) ??
          (p == null ? null : p[1]),
      dLat: _num(d, const [
            'dropOffLat',
            'dropoffLat',
            'dropoffLatitude',
            'destinationLat',
            'destinationLatitude',
          ]) ??
          (o == null ? null : o[0]),
      dLng: _num(d, const [
            'dropOffLng',
            'dropoffLng',
            'dropoffLongitude',
            'destinationLng',
            'destinationLongitude',
          ]) ??
          (o == null ? null : o[1]),
    );
  }

  String _car(Map<String, dynamic> d) {
    final direct = _text(d, const [
      'carDetails',
      'car_details',
      'vehicleDetails',
      'vehicle_details',
    ]);
    if (direct.isNotEmpty) return direct;

    final nested = d['driverDetails'] ?? d['driver_details'];
    if (nested is Map) {
      for (final k in const ['carModel', 'car_model', 'model', 'vehicle', 'name']) {
        final v = nested[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
    }
    return 'ثبت نشده';
  }

  List<double>? _point(dynamic v) {
    if (v is GeoPoint) return [v.latitude, v.longitude];
    if (v is Map) {
      final la = _toDouble(v['latitude'] ?? v['lat']);
      final lo = _toDouble(v['longitude'] ?? v['lng'] ?? v['lon']);
      if (la != null && lo != null) return [la, lo];
    }
    return null;
  }

  double? _num(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = _toDouble(d[k]);
      if (v != null) return v;
    }
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  dynamic _value(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      if (d[k] != null) return d[k];
    }
    return null;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Timestamp? _timestamp(Map<String, dynamic> d) {
    final date = _toDate(_value(d, _dateKeys));
    return date == null ? null : Timestamp.fromDate(date);
  }

  String _money(String raw) {
    final n = AdminFormat.toNumber(raw);
    return n == null ? AdminFormat.toFa(raw) : AdminFormat.money(n);
  }

  String _formatDate(dynamic v) {
    if (v == null) return 'بدون تاریخ';
    final d = _toDate(v);
    if (d == null) return v.toString();
    return AdminFormat.jalaliDateTime(d);
  }

  String _text(
    Map<String, dynamic> d,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final k in keys) {
      final v = d[k];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num || v is bool) return v.toString();
      if (v is Map) {
        for (final n in const ['name', 'title', 'value', 'text', 'model']) {
          final x = v[n];
          if (x != null && x.toString().trim().isNotEmpty) {
            return x.toString().trim();
          }
        }
      }
    }
    return fallback;
  }
}

class _Trip {
  final String id;
  final String passenger;
  final String driver;
  final String car;
  final String dateText;
  final String fare;
  final double? pLat;
  final double? pLng;
  final double? dLat;
  final double? dLng;

  const _Trip({
    required this.id,
    required this.passenger,
    required this.driver,
    required this.car,
    required this.dateText,
    required this.fare,
    required this.pLat,
    required this.pLng,
    required this.dLat,
    required this.dLng,
  });

  bool get hasCoordinates =>
      pLat != null && pLng != null && dLat != null && dLng != null;
}
