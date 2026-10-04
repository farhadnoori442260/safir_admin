import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/methods/common_methods.dart';

class UsersDataList extends StatefulWidget {
  const UsersDataList({super.key});

  @override
  State<UsersDataList> createState() => _UsersDataListState();
}

class _UsersDataListState extends State<UsersDataList> {
  // 📍 دریافت لیست مسافران از کلکسیون users در Firestore
  final Stream<QuerySnapshot> _usersStream =
      FirebaseFirestore.instance.collection("users").snapshots();

  // متد تغییر وضعیت مسدودی مسافر در Firestore (پشتیبانی کامل از تمام حالت‌ها)
  Future<void> _toggleBlockStatus(String userId, bool isCurrentlyBlocked) async {
    bool newBlockState = !isCurrentlyBlocked;
    
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .update({
        'blockStatus': newBlockState ? "yes" : "no",
        'isBlocked': newBlockState,
        'status': newBlockState ? "blocked" : "active",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newBlockState ? 'user_blocked_msg'.tr() : 'user_unblocked_msg'.tr(),
            ),
            backgroundColor: newBlockState ? Colors.red : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
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
            icon: Icons.people_outline_rounded,
            message: 'no_users_registered'.tr(),
            color: Colors.grey.shade500,
          );
        }

        // ---------------- DATA PARSING FROM FIRESTORE ----------------
        var userDocs = snapshotData.data!.docs;

        // ---------------- LIST BUILDER ----------------
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: userDocs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            var doc = userDocs[index];
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            String userId = doc.id;

            // 📍 استخراج هوشمند نام کاربر
            String name = userData["name"] ?? 
                           userData["userName"] ?? 
                           userData["full_name"] ?? 
                           userData["fullName"] ?? 
                           'unknown'.tr();

            // 📍 بررسی هوشمند وضعیت مسدودی
            var blockVal = userData["blockStatus"] ?? userData["status"] ?? userData["isBlocked"];
            bool isBlocked = blockVal == "yes" || blockVal == "blocked" || blockVal == true;

            // 📍 استخراج شماره تماس
            String phone = userData["phone"] ?? 
                           userData["phoneNumber"] ?? 
                           userData["phone_number"] ?? 
                           userData["mobile"] ?? 
                           'not_registered'.tr();

            // 📍 استخراج ایمیل
            String email = userData["email"] ?? 'not_registered'.tr();

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
                    // نام مسافر
                    CommonMethods.data(
                      1,
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // ایمیل
                    CommonMethods.data(
                      1,
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                    // شماره تماس
                    CommonMethods.data(
                      1,
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // دکمه مسدود / رفع مسدودی
                    CommonMethods.data(
                      1,
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBlocked
                                ? AppColors.primary // رفع مسدودی با سبز سفیر
                                : Colors.red.shade600, // مسدود کردن با قرمز
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _toggleBlockStatus(userId, isBlocked),
                          child: Text(
                            isBlocked ? 'unblock_action'.tr() : 'block_action'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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

  // ویجت نمایش پیام‌های خطا و حالت‌های خالی
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
