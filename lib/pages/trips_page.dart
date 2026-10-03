import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/methods/common_methods.dart';

class TripsPage extends StatefulWidget {
  static const String id = "webPageTrips";
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  // متصل شدن به مجموعه rides در Cloud Firestore
  final Stream<QuerySnapshot> _tripsStream = 
      FirebaseFirestore.instance.collection('rides').snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      body: Padding(
        padding: const EdgeInsets.all(24.0), 
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- HEADER SECTION ----------------
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.alt_route_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'active_rides'.tr(),
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'trips_subtitle'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------------- TABLE HEADER CARD ----------------
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary, 
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      CommonMethods.header(1, 'trip_id'.tr()),
                      CommonMethods.header(1, 'driver_name'.tr()),
                      CommonMethods.header(1, 'user_name'.tr()),
                      CommonMethods.header(1, 'origin'.tr()),
                      CommonMethods.header(1, 'destination'.tr()),
                      CommonMethods.header(1, 'fare'.tr()),
                      CommonMethods.header(1, 'date'.tr()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ---------------- DATA LIST FROM FIRESTORE ----------------
              StreamBuilder<QuerySnapshot>(
                stream: _tripsStream,
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text("خطا در دریافت اطلاعات: ${snapshot.error}"),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          "هیچ سفری یافت نشد",
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var tripDoc = snapshot.data!.docs[index];
                      Map<String, dynamic> trip = tripDoc.data() as Map<String, dynamic>;
                      
                      String docId = tripDoc.id;
                      String shortId = docId.substring(0, docId.length > 6 ? 6 : docId.length);

                      // 📍 استخراج هوشمند تمام کلیدها برای راننده و مسافر
                      String driverName = trip['driverName'] ?? 
                                         trip['driver_name'] ?? 
                                         trip['driverDetails']?['name'] ?? 
                                         trip['driverId'] ?? 
                                         trip['driver_id'] ?? 
                                         'در انتظار راننده';

                      String userName = trip['userName'] ?? 
                                       trip['user_name'] ?? 
                                       trip['passengerName'] ?? 
                                       trip['passenger_name'] ?? 
                                       trip['name'] ?? 
                                       trip['userId'] ?? 
                                       trip['user_id'] ?? 
                                       'نامشخص';

                      // 📍 بررسی هوشمند تمام کلیدهای ممکن برای مبدأ، مقصد و زمان
                      String origin = trip['originAddress'] ?? 
                                      trip['origin_address'] ?? 
                                      trip['pickUpAddress'] ?? 
                                      trip['pickup_address'] ?? 
                                      trip['origin_name'] ?? 
                                      trip['origin'] ?? '-';

                      String destination = trip['destinationAddress'] ?? 
                                           trip['destination_address'] ?? 
                                           trip['dropOffAddress'] ?? 
                                           trip['dropoff_address'] ?? 
                                           trip['destination_name'] ?? 
                                           trip['destination'] ?? '-';

                      String time = trip['time'] ?? 
                                    trip['created_at'] ?? 
                                    trip['time_stamp'] ?? 
                                    trip['date'] ?? 
                                    trip['formattedTime'] ?? '-';

                      String fare = trip['fareAmount']?.toString() ?? 
                                    trip['fare']?.toString() ?? 
                                    trip['price']?.toString() ?? '0';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CommonMethods.data(1, Text(shortId, style: const TextStyle(fontWeight: FontWeight.bold))),
                            CommonMethods.data(1, Text(driverName)),
                            CommonMethods.data(1, Text(userName)),
                            CommonMethods.data(1, Text(origin, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            CommonMethods.data(1, Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            CommonMethods.data(1, Text(fare)),
                            CommonMethods.data(1, Text(time)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
