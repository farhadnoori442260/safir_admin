import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart'; // 👈 مسیر AppColors را چک کنید

class CommonMethods {
  // ویجت هدر (سربرگ) جداول با رنگ‌بندی اختصاصی سفیر
  static Widget header(int headerFlexValue, String headerTitle) {
    return Expanded(
      flex: headerFlexValue,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary, // 👈 استفاده از سبز اصلی برند سفیر
          border: Border.all(
            color: Colors.white24,
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Text(
            headerTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.buttonText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ویجت سلول‌های داده جداول
  static Widget data(int headerFlexValue, Widget widget) {
    return Expanded(
      flex: headerFlexValue,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.12), // بوردر ملایم و شیک
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: widget,
        ),
      ),
    );
  }
}
