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
  // 📍 جریان دریافت سفرهای پایان‌یافته (ended) از Firestore
  final Stream<QuerySnapshot> _tripsStream = FirebaseFirestore.instance
      .collection("tripRequests")
      .where("status", isEqualTo: "ended")
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

    // ساخت URL مسیریابی در OpenStreetMap
    String osmUrl =
        "https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=$pickUpLat%2C$pickUpLng%3B$dropOffLat%2C$dropOffLng";

    Uri url = Uri.parse(osmUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("خطا: نقشه OpenStreetMap لود نشد.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _tripsStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshotData) {
        // ---------------- ERROR HANDLERS ----------------
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

        // ---------------- DATA PARSING FROM FIRESTORE ----------------
        var tripDocs = snapshotData.data!.docs;

        // ---------------- LIST BUILDER ----------------
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tripDocs.length,
          padding: const EdgeInsets.only(bottom: 16),
          itemBuilder: (context, index) {
            var doc = tripDocs[index];
            Map<String, dynamic> tripData = doc.data() as Map<String, dynamic>;

            // فرمت کرایه
            var fareAmount = tripData["fareAmount"] ?? tripData["fare"];
            String fareText = fareAmount != null
                ? "$fareAmount ${'afghani_currency'.tr()}"
                : "0 ${'afghani_currency'.tr()}";

            // استخراج مختصات مبدا و مقصد (پشتیبانی از GeoPoint و Map)
            dynamic pickUpLat, pickUpLng, dropOffLat, dropOffLng;

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
                        tripData["tripID"]?.toString() ?? doc.id.substring(0, 8),
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
                        tripData["userName"]?.toString() ?? 'unknown'.tr(),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),

                    // نام راننده
                    CommonMethods.data(
                      1,
                      Text(
                        tripData["driverName"]?.toString() ?? 'unknown'.tr(),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),

                    // مشخصات خودرو
                    CommonMethods.data(
                      1,
                      Text(
                        tripData["carDetails"]?.toString() ?? 'not_registered'.tr(),
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ),

                    // تاریخ و زمان
                    CommonMethods.data(
                      1,
                      Text(
                        tripData["publishDateTime"]?.toString() ??
                            tripData["time"]?.toString() ??
                            'no_date'.tr(),
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

  // ویجت نمایش پیام‌های حالت خالی و خطا
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
