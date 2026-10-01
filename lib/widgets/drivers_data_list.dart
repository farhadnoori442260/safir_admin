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

  Future<void> _updateDriverStatus({
    required String driverId,
    required String statusKey,
    required dynamic statusValue,
    required String successMessage,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection("drivers")
          .doc(driverId)
          .update({statusKey: statusValue});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
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

  void _showImageDialog(
      BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
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
          String name = (data["name"] ?? '').toString().toLowerCase();
          String phone = (data["phone"] ?? '').toString().toLowerCase();
          bool isApproved = data["isApproved"] ?? false;
          bool isBlocked = data["isBlocked"] ?? false;

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

            bool isApproved = driverData["isApproved"] ?? false;
            bool isBlocked = driverData["isBlocked"] ?? false;

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
                        doc.id.substring(0, 6),
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
                            backgroundImage: driverData["photoUrl"] != null
                                ? NetworkImage(driverData["photoUrl"])
                                : null,
                            child: driverData["photoUrl"] == null
                                ? const Icon(Icons.person, size: 18, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              driverData["name"]?.toString() ?? 'unknown'.tr(),
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
                        driverData["phone"]?.toString() ?? '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),

                    // مشخصات خودرو
                    CommonMethods.data(
                      1,
                      Text(
                        "${driverData["carModel"] ?? ''} ${driverData["carColor"] ?? ''}",
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
                          if (driverData["idCardUrl"] != null) {
                            _showImageDialog(
                              context,
                              driverData["idCardUrl"],
                              "مدرک راننده",
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("تصویری ثبت نشده است.")),
                            );
                          }
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
                              _updateDriverStatus(
                                driverId: doc.id,
                                statusKey: "isApproved",
                                statusValue: !isApproved,
                                successMessage: isApproved
                                    ? "وضعیت مدارک به 'در انتظار' تغییر یافت"
                                    : "مدارک راننده با موفقیت تأیید شد",
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
                              _updateDriverStatus(
                                driverId: doc.id,
                                statusKey: "isBlocked",
                                statusValue: !isBlocked,
                                successMessage: isBlocked
                                    ? "راننده از حالت مسدود خارج شد"
                                    : "راننده مسدود شد",
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
