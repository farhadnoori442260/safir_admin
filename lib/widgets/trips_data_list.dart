import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/methods/common_methods.dart';
import 'package:url_launcher/url_launcher.dart';

class TripsDataList extends StatefulWidget {
  const TripsDataList({super.key});

  @override
  State<TripsDataList> createState() => _TripsDataListState();
}

class _TripsDataListState extends State<TripsDataList> {
  // 📍 جریان دریافت تمام درخواستی‌های سفر از Firestore
  final Stream<QuerySnapshot> _tripsStream = FirebaseFirestore.instance
      .collection("tripRequests")
      .snapshots();

  // 🗺️ متد مسیریابی و نمایش مبدا و مقصد روی OpenStreetMap
  Future<void> launchOpenStreetMapFromSourceToDestination(
    dynamic pickUpLat,
    dynamic pickUpLng,
    dynamic dropOffLat,
    dynamic dropOffLng,
  ) async {
    if (pickUpLat == null || pickUpLng == null || dropOffLat == null || dropOffLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("مختصات مبدا یا مقصد کامل نیست.")),
        );
      }
      return;
    }

    String osmUrl =
        "https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=$pickUpLat%2C$pickUpLng%3B$dropOffLat%2C$dropOffLng";

    Uri url = Uri.parse(osmUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("خطا: نقشه OpenStreetMap لود نشد.");
    }
  }

  // 🗓️ تابع کمکی فرمت تاریخ
  String _formatDateTime(dynamic dateTimeVal) {
    if (dateTimeVal == null) return 'no_date'.tr();
    if (dateTimeVal is Timestamp) {
      DateTime dt = dateTimeVal.toDate();
      return "${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return dateTimeVal.toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _tripsStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshotData) {
        if (snapshotData.hasError) {
          debugPrint("Error: ${snapshotData.error}");
          return _buildStateMessage(
            icon: Icons.error_outline_rounded,
            message: 'error_occurred'.tr(),
            color: Colors.red.shade400,
          );
        }

        if (snapshotData.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (!snapshotData.hasData || snapshotData.data!.docs.isEmpty) {
          return _buildStateMessage(
            icon: Icons.route_outlined,
            message: 'no_completed_trips'.tr(),
            color: Colors.grey.shade500,
          );
        }

        // ----------------- فیلتر سفرهای پایان یافته -----------------
        var allDocs = snapshotData.data!.docs;
        var completedTrips = allDocs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String status = (data["status"] ?? '').toString().toLowerCase();
          return status == "ended" || status == "completed" || status == "arrived";
        }).toList();

        if (completedTrips.isEmpty) {
          return _buildStateMessage(
            icon: Icons.route_outlined,
            message: 'no_completed_trips'.tr(),
            color: Colors.grey.shade500,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: completedTrips.length,
          padding: const EdgeInsets.only(bottom: 16),
          itemBuilder: (context, index) {
            var doc = completedTrips[index];
            Map<String, dynamic> tripData = doc.data() as Map<String, dynamic>;

            // استخراج هوشمند اطلاعات
            String tripId = tripData["tripID"]?.toString() ?? 
                            tripData["tripId"]?.toString() ?? 
                            doc.id.substring(0, doc.id.length > 8 ? 8 : doc.id.length);

            String userName = tripData["userName"] ?? 
                               tripData["passengerName"] ?? 
                               tripData["name"] ?? 
                               'unknown'.tr();

            String driverName = tripData["driverName"] ?? 
                                 tripData["driver_name"] ?? 
                                 'unknown'.tr();

            String carDetails = tripData["carDetails"] ?? 
                                tripData["car_details"] ?? 
                                tripData["driverDetails"]?["carModel"] ?? 
                                'not_registered'.tr();

            // فرمت کرایه
            var fareAmount = tripData["fareAmount"] ?? tripData["fare"] ?? tripData["price"];
            String fareText = fareAmount != null
                ? "$fareAmount ${'afghani_currency'.tr()}"
                : "0 ${'afghani_currency'.tr()}";

            // استخراج جامع مختصات مبدا و مقصد
            dynamic pickUpLat = tripData["pickUpLat"] ?? tripData["originLat"];
            dynamic pickUpLng = tripData["pickUpLng"] ?? tripData["originLng"];
            dynamic dropOffLat = tripData["dropOffLat"] ?? tripData["destinationLat"];
            dynamic dropOffLng = tripData["dropOffLng"] ?? tripData["destinationLng"];

            if (tripData["pickUpLatLng"] is Map) {
              pickUpLat = tripData["pickUpLatLng"]["latitude"];
              pickUpLng = tripData["pickUpLatLng"]["longitude"];
            } else if (tripData["pickUpLatLng"] is GeoPoint) {
              pickUpLat = (tripData["pickUpLatLng"] as GeoPoint).latitude;
              pickUpLng = (tripData["pickUpLatLng"] as GeoPoint).longitude;
            }

            if (tripData["dropOffLatLng"] is Map) {
              dropOffLat = tripData["dropOffLatLng"]["latitude"];
              dropOffLng = tripData["dropOffLatLng"]["longitude"];
            } else if (tripData["dropOffLatLng"] is GeoPoint) {
              dropOffLat = (tripData["dropOffLatLng"] as GeoPoint).latitude;
              dropOffLng = (tripData["dropOffLatLng"] as GeoPoint).longitude;
            }

            // تاریخ و زمان
            String timeText = _formatDateTime(
              tripData["publishDateTime"] ?? tripData["time"] ?? tripData["createdAt"]
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // شناسه سفر
                    CommonMethods.data(
                      2,
                      Text(
                        tripId,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // نام مسافر
                    CommonMethods.data(
                      1,
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),

                    // نام راننده
                    CommonMethods.data(
                      1,
                      Text(
                        driverName,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),

                    // مشخصات خودرو
                    CommonMethods.data(
                      1,
                      Text(
                        carDetails,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ),

                    // تاریخ و زمان
                    CommonMethods.data(
                      1,
                      Text(
                        timeText,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),

                    // مبلغ کرایه
                    CommonMethods.data(
                      1,
                      Text(
                        fareText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // دکمه مشاهده مسیر روی OpenStreetMap
                    CommonMethods.data(
                      1,
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.08),
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () {
                            launchOpenStreetMapFromSourceToDestination(
                              pickUpLat,
                              pickUpLng,
                              dropOffLat,
                              dropOffLng,
                            );
                          },
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: Text(
                            'more_details'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
