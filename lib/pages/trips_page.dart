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
  // 📍 جریان دریافت تمام سفرهای ثبت‌شده در کلاکشن rides به صورت نزولی (جدیدترین‌ها اول)
  final Stream<QuerySnapshot> _tripsStream = FirebaseFirestore.instance
      .collection('rides')
      .snapshots();

  // 🏷️ ویجت نشان‌دهنده وضعیت سفر با رنگ اختصاصی
  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'searching':
        chipColor = Colors.orange;
        statusText = 'در حال جستجوی راننده';
        break;
      case 'accepted':
        chipColor = Colors.blue;
        statusText = 'پذیرفته شده';
        break;
      case 'arrived':
        chipColor = Colors.purple;
        statusText = 'راننده در مبدأ';
        break;
      case 'ontrip':
      case 'on_trip':
        chipColor = Colors.indigo;
        statusText = 'در حال سفر';
        break;
      case 'completed':
      case 'ended':
        chipColor = Colors.green;
        statusText = 'پایان یافته';
        break;
      case 'cancelledbypassenger':
      case 'cancelled_by_passenger':
        chipColor = Colors.red;
        statusText = 'لغو توسط مسافر';
        break;
      case 'cancelledbydriver':
      case 'cancelled_by_driver':
        chipColor = Colors.red;
        statusText = 'لغو توسط راننده';
        break;
      default:
        chipColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: chipColor,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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
                        'مدیریت و مشاهده تمام سفرهای درخواست‌شده و فعال سفیر',
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

              // ---------------- TABLE WITH HORIZONTAL SCROLL ----------------
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 900, // جهت جلوگیری از اسکرول خوردن ناخواسته و Overflow
                  child: Column(
                    children: [
                      // TABLE HEADER CARD
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
                              CommonMethods.header(1, 'کد سفر'),
                              CommonMethods.header(1, 'نام مسافر'),
                              CommonMethods.header(1, 'نام راننده'),
                              CommonMethods.header(2, 'مبدأ'),
                              CommonMethods.header(2, 'مقصد'),
                              CommonMethods.header(1, 'کرایه'),
                              CommonMethods.header(1, 'وضعیت'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // DATA LIST FROM FIRESTORE
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

                          var docs = snapshot.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var tripDoc = docs[index];
                              Map<String, dynamic> trip = tripDoc.data() as Map<String, dynamic>;
                              
                              String docId = tripDoc.id;
                              String shortId = docId.substring(0, docId.length > 6 ? 6 : docId.length);

                              // 📍 استخراج دقیق اطلاعات طبق ساختار اپلیکیشن مسافر
                              String passengerName = trip['passenger_name'] ?? 
                                                     trip['userName'] ?? 
                                                     trip['passengerName'] ?? 
                                                     'نامشخص';

                              String driverName = trip['driver_name'] ?? 
                                                   trip['driverName'] ?? 
                                                   (trip['driver_id'] == 'waiting' ? 'در انتظار راننده' : 'تخصیص‌نیافته');

                              String origin = trip['originAddress'] ?? 
                                              trip['origin_address'] ?? 
                                              trip['pickup_address'] ?? '-';

                              String destination = trip['destinationAddress'] ?? 
                                                   trip['destination_address'] ?? 
                                                   trip['dropoff_address'] ?? '-';

                              String fare = trip['fareAmount']?.toString() ?? 
                                            trip['fare']?.toString() ?? 
                                            trip['price']?.toString() ?? '0';

                              String status = trip['status']?.toString() ?? 'searching';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      CommonMethods.data(1, Text(shortId, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      CommonMethods.data(1, Text(passengerName)),
                                      CommonMethods.data(1, Text(driverName)),
                                      CommonMethods.data(2, Text(origin, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      CommonMethods.data(2, Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      CommonMethods.data(1, Text("$fare افغانی")),
                                      CommonMethods.data(1, _buildStatusChip(status)),
                                    ],
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
