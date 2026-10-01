import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  // ارجاع به شاخه کاربران در فایربیس سفیر
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child("users");

  /// متد تغییر وضعیت مسدودیت مسافر (بلاک / آنبلاک)
  Future<bool> toggleBlockStatus(String userId, String? currentStatus) async {
    // تبدیل وضعیت: اگر "no" بود به "yes" (مسدود) و بالعکس
    String newStatus = currentStatus == "no" ? "yes" : "no";

    try {
      // به‌روزرسانی در شاخه کاربران دیتابیس فایربیس سفیر
      await _usersRef.child(userId).update({
        "blockStatus": newStatus,
      });

      notifyListeners(); // به‌روزرسانی هوشمند ویجت‌های متصل به این پرووایدر
      return true; // عملیات موفقیت‌آمیز بود
    } catch (error) {
      debugPrint("خطا در تغییر وضعیت مسدودیت مسافر: $error");
      return false; // عملیات با خطا مواجه شد
    }
  }
}
