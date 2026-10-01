import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 استفاده از Cloud Firestore
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';

class DriverDataScreen extends StatefulWidget {
  final String driverId;

  const DriverDataScreen({super.key, required this.driverId});

  @override
  State<DriverDataScreen> createState() => _DriverDataScreenState();
}

class _DriverDataScreenState extends State<DriverDataScreen> {
  @override
  Widget build(BuildContext context) {
    // 📍 اتصال به سند راننده در Cloud Firestore
    DocumentReference driverRef =
        FirebaseFirestore.instance.collection("drivers").doc(widget.driverId);

    return StreamBuilder<DocumentSnapshot>(
      stream: driverRef.snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshotData) {
        if (snapshotData.hasError) {
          return Center(
            child: Text(
              'error_occurred'.tr(),
              style: const TextStyle(fontSize: 18, color: Colors.red),
            ),
          );
        }

        if (snapshotData.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (!snapshotData.hasData || !snapshotData.data!.exists) {
          return Center(
            child: Text(
              'no_data_found'.tr(),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        Map<String, dynamic> dataMap = snapshotData.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            automaticallyImplyLeading: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
            elevation: 0,
            title: Text(
              'driver_details'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. کارت پروفایل اصلی
                _buildCardWrapper(
                  child: _buildProfileSection(dataMap),
                ),
                const SizedBox(height: 20),

                // 2. کارت مدارک هویتی
                _buildCardWrapper(
                  title: 'identity_docs'.tr(),
                  icon: Icons.badge_outlined,
                  child: _buildNationalIdSection(dataMap),
                ),
                const SizedBox(height: 20),

                // 3. کارت گواهینامه
                _buildCardWrapper(
                  title: 'driving_license'.tr(),
                  icon: Icons.card_membership_rounded,
                  child: _buildLicenseSection(dataMap),
                ),
                const SizedBox(height: 20),

                // 4. کارت مشخصات خودرو
                _buildCardWrapper(
                  title: 'vehicle_info_title'.tr(),
                  icon: Icons.directions_car_filled_outlined,
                  child: _buildVehicleInfoSection(dataMap),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ویجت قاب‌کننده (کارت مدرن) برای یکدست‌سازی بخش‌ها
  Widget _buildCardWrapper({
    String? title,
    IconData? icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.8),
          ],
          child,
        ],
      ),
    );
  }

  // بخش پروفایل اصلی
  Widget _buildProfileSection(Map<String, dynamic> dataMap) {
    String firstName = dataMap['firstName'] ?? dataMap['name'] ?? '';
    String secondName = dataMap['secondName'] ?? '';
    String notReg = 'not_registered'.tr();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: ClipOval(
            child: (dataMap.containsKey('profilePicture') &&
                    dataMap['profilePicture'] != null &&
                    dataMap['profilePicture'].toString().isNotEmpty)
                ? Image.network(
                    dataMap['profilePicture'],
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.account_circle,
                      size: 110,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.account_circle,
                    size: 110,
                    color: AppColors.primary,
                  ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$firstName $secondName".trim(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _buildInfoRow('phone'.tr(), dataMap['phoneNumber'] ?? dataMap['phone'] ?? notReg),
                  _buildInfoRow('email'.tr(), dataMap['email'] ?? notReg),
                  _buildInfoRow('national_id'.tr(), dataMap['cnicNumber'] ?? notReg),
                  _buildInfoRow('address'.tr(), dataMap['address'] ?? notReg),
                  _buildInfoRow('dob'.tr(), dataMap['dob'] ?? notReg),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // بخش مدارک هویتی
  Widget _buildNationalIdSection(Map<String, dynamic> dataMap) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildImageCard(dataMap['cnicFrontImage'], 'id_front'.tr()),
        _buildImageCard(dataMap['cnicBackImage'], 'id_back'.tr()),
        _buildImageCard(dataMap['driverFaceWithCnic'], 'selfie_with_id'.tr()),
      ],
    );
  }

  // بخش گواهینامه
  Widget _buildLicenseSection(Map<String, dynamic> dataMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('license_number'.tr(),
            dataMap['drivingLicenseNumber'] ?? 'not_registered'.tr()),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildImageCard(dataMap['drivingLicenseFrontImage'], 'license_front'.tr()),
            _buildImageCard(dataMap['drivingLicenseBackImage'], 'license_back'.tr()),
          ],
        ),
      ],
    );
  }

  // مشخصات خودرو
  Widget _buildVehicleInfoSection(Map<String, dynamic> dataMap) {
    if (!dataMap.containsKey('vehicleInfo') || dataMap['vehicleInfo'] == null) {
      return Text(
        'vehicle_not_registered'.tr(),
        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    Map<String, dynamic> vehicle = Map<String, dynamic>.from(dataMap['vehicleInfo']);
    String notReg = 'not_registered'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _buildInfoRow('vehicle_type'.tr(), vehicle['type'] ?? notReg),
            _buildInfoRow('vehicle_brand'.tr(), vehicle['brand'] ?? notReg),
            _buildInfoRow('vehicle_color'.tr(), vehicle['color'] ?? notReg),
            _buildInfoRow('production_year'.tr(), vehicle['productionYear'] ?? notReg),
            _buildInfoRow('plate_number'.tr(), vehicle['registrationPlateNumber'] ?? notReg),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildImageCard(
                vehicle['registrationCertificateFrontImage'], 'car_card_front'.tr()),
            _buildImageCard(
                vehicle['registrationCertificateBackImage'], 'car_card_back'.tr()),
          ],
        ),
      ],
    );
  }

  // سطر‌های نمایش داده
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          children: [
            TextSpan(
              text: "$label: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // کارت پیش‌نمایش تصویر
  Widget _buildImageCard(dynamic url, String label) {
    bool hasUrl = url != null && url.toString().isNotEmpty;

    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasUrl
                ? Image.network(
                    url.toString(),
                    width: 154,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 154,
                      height: 110,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.red),
                    ),
                  )
                : Container(
                    width: 154,
                    height: 110,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
