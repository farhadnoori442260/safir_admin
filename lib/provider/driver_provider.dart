import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class DriverProvider with ChangeNotifier {
  final DatabaseReference _driversRef =
      FirebaseDatabase.instance.ref().child("drivers");

  /// متد تغییر وضعیت مسدودیت راننده (بلاک / آنبلاک)
  Future<bool> toggleBlockStatus(String driverId, String? currentStatus) async {
    // تبدیل وضعیت: اگر "no" بود به "yes" (مسدود) و بالعکس
    String newStatus = currentStatus == "no" ? "yes" : "no";

    try {
      // به‌روزرسانی در دیتابیس فایربیس سفیر
      await _driversRef.child(driverId).update({
        "blockStatus": newStatus,
      });

      notifyListeners(); // باخبر کردن ویجت‌ها برای به‌روزرسانی آنی پنل
      return true; // تغییر با موفقیت انجام شد
    } catch (error) {
      debugPrint("خطا در تغییر وضعیت راننده: $error");
      return false; // عملیات با خطا مواجه شد
    }
  }
}
