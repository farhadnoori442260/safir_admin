import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/methods/common_methods.dart';
import 'package:safir_admin/widgets/drivers_data_list.dart';

class DriverPage extends StatefulWidget {
  static const String id = "webPageDrivers";
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, pending, approved, blocked

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'manage_drivers'.tr(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مدیریت و بررسی مدارک رانندگان سفیر',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------------- SEARCH & FILTER BAR ----------------
              Row(
                children: [
                  // کادر جستجو
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "جستجو بر اساس نام یا شماره تلفن...",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // منوی کشویی فیلتر
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        icon: const Icon(Icons.filter_list, color: AppColors.primary),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFilter = newValue;
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text("همه رانندگان")),
                          DropdownMenuItem(value: 'pending', child: Text("در انتظار تأیید")),
                          DropdownMenuItem(value: 'approved', child: Text("تأیید شده")),
                          DropdownMenuItem(value: 'blocked', child: Text("مسدود شده")),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---------------- TABLE WITH HORIZONTAL SCROLL ----------------
              // 👈 اضافه کردن اسکرول افقی برای جلوگیری از overflow در گوشی
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 850, // تعیین حداقل عرض برای جا شدن کامل ستون‌ها
                  child: Column(
                    children: [
                      // HEADER CARD
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              CommonMethods.header(1, 'کد'),
                              CommonMethods.header(2, 'نام راننده'),
                              CommonMethods.header(1, 'شماره تماس'),
                              CommonMethods.header(1, 'خودرو'),
                              CommonMethods.header(1, 'وضعیت'),
                              CommonMethods.header(1, 'مدارک'),
                              CommonMethods.header(2, 'عملیات'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // DATA LIST
                      DriversDataList(
                        searchQuery: _searchQuery,
                        filterStatus: _selectedFilter,
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
