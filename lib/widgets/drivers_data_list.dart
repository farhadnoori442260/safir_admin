import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/methods/common_methods.dart';

class DriversDataList extends StatefulWidget {
  final String searchQuery;
  final String filterStatus; // 'all', 'pending', 'approved', 'blocked'

  const DriversDataList({
    super.key,
    this.searchQuery = '',
    this.filterStatus = 'all',
  });

  @override
  State<DriversDataList> createState() => _DriversDataListState();
}

class _DriversDataListState extends State<DriversDataList> {
  final Stream<QuerySnapshot> _driversStream =
      FirebaseFirestore.instance.collection("drivers").snapshots();

  // 📍 متد هوشمند به‌روزرسانی وضعیت راننده در تمام فیلدهای ممکن
  Future<void> _updateDriverApproval({
    required String driverId,
    required bool currentApproved,
  }) async {
    bool newStatus = !currentApproved;
    try {
      await FirebaseFirestore.instance
          .collection("drivers")
          .doc(driverId)
          .update({
        "isApproved": newStatus,
        "status": newStatus ? "approved" : "pending",
        "newDriverStatus": newStatus ? "approved" : "pending",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? "مدارک راننده با موفقیت تأیید شد"
                  : "وضعیت مدارک به 'در انتظار' تغییر یافت",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطا در به‌روزرسانی: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📍 متد هوشمند تغییر وضعیت مسدودی راننده
  Future<void> _updateDriverBlockStatus({
    required String driverId,
    required bool currentBlocked,
  }) async {
    bool newBlockState = !currentBlocked;
    try {
      await FirebaseFirestore.instance
          .collection("drivers")
          .doc(driverId)
          .update({
        "isBlocked": newBlockState,
        "blockStatus": newBlockState ? "yes" : "no",
        "status": newBlockState ? "blocked" : "approved",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newBlockState
                  ? "راننده مسدود شد"
                  : "راننده از حالت مسدود خارج شد",
            ),
            backgroundColor: newBlockState ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطا در به‌روزرسانی: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📍 نمایش مدارک راننده با پشتیبانی از چندین عکس
  void _showImageDialog(
      BuildContext context, Map<String, dynamic> driverData, String title) {
    List<String> imageUrls = [];

    // جمع‌آوری تمام لینک‌های عکس مدارک موجود در سند راننده
    if (driverData["idCardUrl"] != null) imageUrls.add(driverData["idCardUrl"]);
    if (driverData["id_card_url"] != null) imageUrls.add(driverData["id_card_url"]);
    if (driverData["licenseUrl"] != null) imageUrls.add(driverData["licenseUrl"]);
    if (driverData["license_url"] != null) imageUrls.add(driverData["license_url"]);
    if (driverData["carPhotoUrl"] != null) imageUrls.add(driverData["carPhotoUrl"]);

    imageUrls = imageUrls.toSet().toList(); // حذف موارد تکراری

    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("هیچ تصویری برای مدارک این راننده ثبت نشده است.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: imageUrls.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("بستن"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _driversStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshotData) {
        if (snapshotData.hasError) {
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
            icon: Icons.people_outline,
            message: 'هیچ راننده‌ای یافت نشد',
            color: Colors.grey.shade500,
          );
        }

        // ----------------- فیلتر و جستجوی محلی -----------------
        var allDocs = snapshotData.data!.docs;
        var filteredDocs = allDocs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          String name = (data["name"] ?? data["driver_name"] ?? '').toString().toLowerCase();
          String phone = (data["phone"] ?? data["phoneNumber"] ?? '').toString().toLowerCase();

          var approvedVal = data["isApproved"] ?? data["status"];
          bool isApproved = approvedVal == true || approvedVal == "approved";

          var blockedVal = data["isBlocked"] ?? data["blockStatus"];
          bool isBlocked = blockedVal == true || blockedVal == "yes" || blockedVal == "blocked";

          // ۱. چک کردن متن جستجو
          String query = widget.searchQuery.trim().toLowerCase();
          bool matchesSearch = query.isEmpty ||
              name.contains(query) ||
              phone.contains(query);

          // ۲. چک کردن فیلتر وضعیت
          bool matchesFilter = true;
          if (widget.filterStatus == 'pending') {
            matchesFilter = !isApproved && !isBlocked;
          } else if (widget.filterStatus == 'approved') {
            matchesFilter = isApproved && !isBlocked;
          } else if (widget.filterStatus == 'blocked') {
            matchesFilter = isBlocked;
          }

          return matchesSearch && matchesFilter;
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildStateMessage(
            icon: Icons.search_off_rounded,
            message: 'نتیجه‌ای با این مشخصات یافت نشد',
            color: Colors.grey.shade500,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          padding: const EdgeInsets.only(bottom: 16),
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            Map<String, dynamic> driverData = doc.data() as Map<String, dynamic>;

            // 📍 استخراج هوشمند پارامترها
            String driverName = driverData["name"] ?? driverData["driver_name"] ?? 'unknown'.tr();
            String phone = driverData["phone"] ?? driverData["phoneNumber"] ?? '-';
            
            String carModel = driverData["carModel"] ?? driverData["car_model"] ?? driverData["carDetails"]?["carModel"] ?? '';
            String carColor = driverData["carColor"] ?? driverData["car_color"] ?? driverData["carDetails"]?["carColor"] ?? '';
            String carInfo = "$carModel $carColor".trim();
            if (carInfo.isEmpty) carInfo = "-";

            String? photoUrl = driverData["photoUrl"] ?? driverData["photo_url"] ?? driverData["user_image"];

            var approvedVal = driverData["isApproved"] ?? driverData["status"];
            bool isApproved = approvedVal == true || approvedVal == "approved";

            var blockedVal = driverData["isBlocked"] ?? driverData["blockStatus"];
            bool isBlocked = blockedVal == true || blockedVal == "yes" || blockedVal == "blocked";

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
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // شناسه راننده
                    CommonMethods.data(
                      1,
                      Text(
                        doc.id.substring(0, doc.id.length > 6 ? 6 : doc.id.length),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // عکس و نام راننده
                    CommonMethods.data(
                      2,
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person, size: 18, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              driverName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // شماره تلفن
                    CommonMethods.data(
                      1,
                      Text(
                        phone,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),

                    // مشخصات خودرو
                    CommonMethods.data(
                      1,
                      Text(
                        carInfo,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),

                    // وضعیت تأیید مدارک
                    CommonMethods.data(
                      1,
                      Chip(
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: isBlocked
                            ? Colors.red.withOpacity(0.1)
                            : (isApproved
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1)),
                        label: Text(
                          isBlocked
                              ? "مسدود شده"
                              : (isApproved ? "تأیید شده" : "در انتظار تأیید"),
                          style: TextStyle(
                            fontSize: 11,
                            color: isBlocked
                                ? Colors.red
                                : (isApproved ? Colors.green : Colors.orange.shade800),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // مشاهده مدارک
                    CommonMethods.data(
                      1,
                      IconButton(
                        icon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                        tooltip: "مشاهده مدارک",
                        onPressed: () {
                          _showImageDialog(
                            context,
                            driverData,
                            "مدارک راننده: $driverName",
                          );
                        },
                      ),
                    ),

                    // دکمه‌های عملیاتی
                    CommonMethods.data(
                      2,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isApproved ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                            ),
                            onPressed: () {
                              _updateDriverApproval(
                                driverId: doc.id,
                                currentApproved: isApproved,
                              );
                            },
                            child: Text(
                              isApproved ? "لغو تأیید" : "تأیید مدارک",
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(
                              isBlocked ? Icons.block : Icons.check_circle_outline,
                              color: isBlocked ? Colors.red : Colors.grey,
                            ),
                            tooltip: isBlocked ? "خروج از مسدودی" : "مسدود کردن راننده",
                            onPressed: () {
                              _updateDriverBlockStatus(
                                driverId: doc.id,
                                currentBlocked: isBlocked,
                              );
                            },
                          ),
                        ],
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
