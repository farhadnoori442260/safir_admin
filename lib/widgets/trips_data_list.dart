import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_admin/constants/app_colors.dart';

class TripsDataList extends StatefulWidget {
  const TripsDataList({super.key});

  @override
  State<TripsDataList> createState() => _TripsDataListState();
}

class _TripsDataListState extends State<TripsDataList> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> _tripsStream =
      FirebaseFirestore.instance.collection('rides').snapshots();

  bool _isOpeningMap = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tripsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStateMessage(
            icon: Icons.error_outline_rounded,
            message: 'خطا در خواندن سفرها:
${snapshot.error}',
            color: Colors.red.shade600,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(42),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final completedTrips = documents.where((document) {
          final status = _normalizeStatus(
            _readText(
              document.data(),
              ['status'],
              fallback: '',
            ),
          );

          return status == 'completed' ||
              status == 'ended' ||
              status == 'finished';
        }).toList();

        if (completedTrips.isEmpty) {
          return _buildStateMessage(
            icon: Icons.route_outlined,
            message: 'no_completed_trips'.tr(),
            color: Colors.grey.shade500,
          );
        }

        completedTrips.sort((a, b) {
          final aTime = _readTimestamp(a.data());
          final bTime = _readTimestamp(b.data());

          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: completedTrips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _buildTripRow(
              context,
              completedTrips[index],
            );
          },
        );
      },
    );
  }

  Widget _buildTripRow(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final trip = _parseTrip(
      document.id,
      document.data(),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: Row(
          children: [
            _dataCell(
              flex: 20,
              child: _buildTripCode(trip.id),
            ),
            _dataCell(
              flex: 15,
              child: _buildPersonCell(
                trip.passengerName,
                Icons.person_outline_rounded,
              ),
            ),
            _dataCell(
              flex: 15,
              child: _buildPersonCell(
                trip.driverName,
                Icons.local_taxi_outlined,
              ),
            ),
            _dataCell(
              flex: 15,
              child: _buildSimpleCell(
                trip.carDetails,
                Icons.directions_car_outlined,
              ),
            ),
            _dataCell(
              flex: 16,
              child: _buildSimpleCell(
                trip.dateText,
                Icons.schedule_rounded,
              ),
            ),
            _dataCell(
              flex: 12,
              child: _buildFare(trip.fare),
            ),
            _dataCell(
              flex: 18,
              child: _buildMapButton(
                context: context,
                trip: trip,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell({
    required int flex,
    required Widget child,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
  }

  Widget _buildTripCode(String id) {
    final shortId = id.length > 8 ? id.substring(0, 8) : id;

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

  Widget _buildSimpleCell(String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 16,
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

  Widget _buildFare(String fare) {
    return Text(
      '$fare ${'afghani_currency'.tr()}',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMapButton({
    required BuildContext context,
    required _CompletedTrip trip,
  }) {
    final hasCoordinates = trip.hasCoordinates;

    return Tooltip(
      message: hasCoordinates
          ? 'نمایش مسیر روی نقشه'
          : 'مختصات مسیر ثبت نشده است',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !hasCoordinates || _isOpeningMap
            ? null
            : () {
                _openOpenStreetMap(
                  context: context,
                  trip: trip,
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: hasCoordinates
                ? AppColors.primary.withOpacity(0.09)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isOpeningMap
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      Icons.map_outlined,
                      size: 17,
                      color: hasCoordinates
                          ? AppColors.primary
                          : Colors.grey,
                    ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  hasCoordinates ? 'مشاهده مسیر' : 'بدون مختصات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasCoordinates
                        ? AppColors.primary
                        : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openOpenStreetMap({
    required BuildContext context,
    required _CompletedTrip trip,
  }) async {
    if (!trip.hasCoordinates) {
      _showSnackBar(
        'مختصات مبدأ یا مقصد این سفر کامل نیست.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isOpeningMap = true;
    });

    final route = [
      '${trip.pickupLatitude},${trip.pickupLongitude}',
      '${trip.dropoffLatitude},${trip.dropoffLongitude}',
    ].join(';');

    final uri = Uri.https(
      'www.openstreetmap.org',
      '/directions',
      {
        'engine': 'fossgis_osrm_car',
        'route': route,
      },
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showSnackBar(
          'بازکردن نقشه امکان‌پذیر نیست.',
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'خطا در بازکردن نقشه: $e',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMap = false;
        });
      }
    }
  }

  _CompletedTrip _parseTrip(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final tripId = _readText(
      data,
      [
        'tripID',
        'tripId',
        'trip_id',
      ],
      fallback: documentId,
    );

    final passengerName = _readText(
      data,
      [
        'passenger_name',
        'passengerName',
        'passengername',
        'userName',
        'username',
        'user_name',
        'name',
      ],
      fallback: 'unknown'.tr(),
    );

    final driverName = _readText(
      data,
      [
        'driver_name',
        'driverName',
        'drivername',
      ],
      fallback: 'unknown'.tr(),
    );

    final carDetails = _readCarDetails(data);

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

    final dateValue = _readValue(
      data,
      [
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
      ],
    );

    final coordinates = _readCoordinates(data);

    return _CompletedTrip(
      id: tripId,
      passengerName: passengerName,
      driverName: driverName,
      carDetails: carDetails,
      fare: fare,
      dateText: _formatDateTime(dateValue),
      pickupLatitude: coordinates.pickupLatitude,
      pickupLongitude: coordinates.pickupLongitude,
      dropoffLatitude: coordinates.dropoffLatitude,
      dropoffLongitude: coordinates.dropoffLongitude,
    );
  }

  String _readCarDetails(Map<String, dynamic> data) {
    final directValue = _readText(
      data,
      [
        'carDetails',
        'car_details',
        'vehicleDetails',
        'vehicle_details',
      ],
    );

    if (directValue.isNotEmpty) {
      return directValue;
    }

    final nested = data['driverDetails'] ?? data['driver_details'];

    if (nested is Map) {
      final value = _readMapText(
        nested,
        [
          'carModel',
          'car_model',
          'model',
          'vehicle',
          'name',
        ],
      );

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'not_registered'.tr();
  }

  _TripCoordinates _readCoordinates(
    Map<String, dynamic> data,
  ) {
    double? pickupLatitude = _readDouble(
      data,
      [
        'pickUpLat',
        'pickupLat',
        'pickupLatitude',
        'originLat',
        'originLatitude',
      ],
    );

    double? pickupLongitude = _readDouble(
      data,
      [
        'pickUpLng',
        'pickupLng',
        'pickupLongitude',
        'originLng',
        'originLongitude',
      ],
    );

    double? dropoffLatitude = _readDouble(
      data,
      [
        'dropOffLat',
        'dropoffLat',
        'dropoffLatitude',
        'destinationLat',
        'destinationLatitude',
      ],
    );

    double? dropoffLongitude = _readDouble(
      data,
      [
        'dropOffLng',
        'dropoffLng',
        'dropoffLongitude',
        'destinationLng',
        'destinationLongitude',
      ],
    );

    final pickupValue = data['pickUpLatLng'] ??
        data['pickupLatLng'] ??
        data['pickupLocation'] ??
        data['originLocation'];

    final dropoffValue = data['dropOffLatLng'] ??
        data['dropoffLatLng'] ??
        data['dropoffLocation'] ??
        data['destinationLocation'];

    final pickupPoint = _readPoint(pickupValue);
    final dropoffPoint = _readPoint(dropoffValue);

    pickupLatitude ??= pickupPoint?.latitude;
    pickupLongitude ??= pickupPoint?.longitude;
    dropoffLatitude ??= dropoffPoint?.latitude;
    dropoffLongitude ??= dropoffPoint?.longitude;

    return _TripCoordinates(
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
    );
  }

  _CoordinatePoint? _readPoint(dynamic value) {
    if (value is GeoPoint) {
      return _CoordinatePoint(
        latitude: value.latitude,
        longitude: value.longitude,
      );
    }

    if (value is Map) {
      final latitude = _toDouble(
        value['latitude'] ?? value['lat'],
      );

      final longitude = _toDouble(
        value['longitude'] ?? value['lng'] ?? value['lon'],
      );

      if (latitude != null && longitude != null) {
        return _CoordinatePoint(
          latitude: latitude,
          longitude: longitude,
        );
      }
    }

    return null;
  }

  double? _readDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _toDouble(data[key]);

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  dynamic _readValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data[key] != null) {
        return data[key];
      }
    }

    return null;
  }

  String _formatDateTime(dynamic value) {
    if (value == null) {
      return 'no_date'.tr();
    }

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return value.toString();
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}/$month/$day $hour:$minute';
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
            'model',
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
    final value = _readValue(
      data,
      [
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
      ],
    );

    if (value is Timestamp) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
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

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
}

class _CompletedTrip {
  final String id;
  final String passengerName;
  final String driverName;
  final String carDetails;
  final String dateText;
  final String fare;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  const _CompletedTrip({
    required this.id,
    required this.passengerName,
    required this.driverName,
    required this.carDetails,
    required this.dateText,
    required this.fare,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
  });

  bool get hasCoordinates =>
      pickupLatitude != null &&
      pickupLongitude != null &&
      dropoffLatitude != null &&
      dropoffLongitude != null;
}

class _TripCoordinates {
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  const _TripCoordinates({
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
  });
}

class _CoordinatePoint {
  final double latitude;
  final double longitude;

  const _CoordinatePoint({
    required this.latitude,
    required this.longitude,
  });
}
