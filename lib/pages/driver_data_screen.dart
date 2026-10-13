import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class DriverDataScreen extends StatefulWidget {
  final String driverId;

  const DriverDataScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverDataScreen> createState() => _DriverDataScreenState();
}

class _DriverDataScreenState extends State<DriverDataScreen> {
  late final DocumentReference<Map<String, dynamic>> _driverReference;

  @override
  void initState() {
    super.initState();

    _driverReference = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverReference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildScaffold(
            body: _buildStateMessage(
              icon: Icons.error_outline_rounded,
              message: 'خطا در دریافت اطلاعات راننده:
${snapshot.error}',
              color: Colors.red.shade600,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildScaffold(
            body: const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final document = snapshot.data;

        if (document == null || !document.exists) {
          return _buildScaffold(
            body: _buildStateMessage(
              icon: Icons.person_off_outlined,
              message: _safeTranslation(
                'no_data_found',
                fallback: 'اطلاعاتی برای این راننده یافت نشد',
              ),
              color: Colors.grey.shade500,
            ),
          );
        }

        final data = document.data() ?? {};

        return _buildScaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 680;

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageTitle(data),
                        const SizedBox(height: 20),
                        _buildProfileCard(
                          data: data,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 18),
                        _buildStatusCard(data),
                        const SizedBox(height: 18),
                        _buildCardWrapper(
                          title: _safeTranslation(
                            'identity_docs',
                            fallback: 'مدارک هویتی',
                          ),
                          icon: Icons.badge_outlined,
                          child: _buildIdentityDocuments(data),
                        ),
                        const SizedBox(height: 18),
                        _buildCardWrapper(
                          title: _safeTranslation(
                            'driving_license',
                            fallback: 'گواهینامه رانندگی',
                          ),
                          icon: Icons.card_membership_rounded,
                          child: _buildLicenseSection(data),
                        ),
                        const SizedBox(height: 18),
                        _buildCardWrapper(
                          title: _safeTranslation(
                            'vehicle_info_title',
                            fallback: 'اطلاعات خودرو',
                          ),
                          icon: Icons.directions_car_filled_outlined,
                          child: _buildVehicleSection(data),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Scaffold _buildScaffold({
    required Widget body,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _safeTranslation(
            'driver_details',
            fallback: 'جزئیات راننده',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildPageTitle(Map<String, dynamic> data) {
    final name = _driverName(data);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.person_search_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مشخصات راننده',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: widget.driverId,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              widget.driverId.length > 8
                  ? widget.driverId.substring(0, 8)
                  : widget.driverId,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required Map<String, dynamic> data,
    required bool isMobile,
  }) {
    final name = _driverName(data);

    final phone = _readText(
      data,
      [
        'phone',
        'phoneNumber',
        'phone_number',
        'mobile',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final email = _readText(
      data,
      [
        'email',
        'emailAddress',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final nationalId = _readText(
      data,
      [
        'cnicNumber',
        'nationalId',
        'national_id',
        'idNumber',
        'id_number',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final address = _readText(
      data,
      [
        'address',
        'homeAddress',
        'home_address',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final birthDate = _formatDate(
      _readValue(
        data,
        [
          'dob',
          'dateOfBirth',
          'date_of_birth',
          'birthDate',
          'birth_date',
        ],
      ),
    );

    final imageUrl = _readNullableText(
      data,
      [
        'profilePicture',
        'photoUrl',
        'photo_url',
        'profileImage',
        'profile_image',
        'user_image',
      ],
    );

    final profileInfo = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اطلاعات شخصی و راه‌های ارتباطی راننده',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _buildInfoItem(
                icon: Icons.phone_outlined,
                label: _safeTranslation('phone', fallback: 'شماره تماس'),
                value: phone,
              ),
              _buildInfoItem(
                icon: Icons.email_outlined,
                label: _safeTranslation('email', fallback: 'ایمیل'),
                value: email,
              ),
              _buildInfoItem(
                icon: Icons.badge_outlined,
                label: _safeTranslation('national_id', fallback: 'شماره تذکره'),
                value: nationalId,
              ),
              _buildInfoItem(
                icon: Icons.location_on_outlined,
                label: _safeTranslation('address', fallback: 'آدرس'),
                value: address,
              ),
              _buildInfoItem(
                icon: Icons.cake_outlined,
                label: _safeTranslation('dob', fallback: 'تاریخ تولد'),
                value: birthDate,
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildProfileAvatar(imageUrl)),
                const SizedBox(height: 18),
                profileInfo,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileAvatar(imageUrl),
                const SizedBox(width: 22),
                profileInfo,
              ],
            ),
    );
  }

  Widget _buildProfileAvatar(String? imageUrl) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary,
          width: 3,
        ),
        color: AppColors.primary.withOpacity(0.08),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;

                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person_outline_rounded,
                    size: 58,
                    color: AppColors.primary,
                  );
                },
              )
            : const Icon(
                Icons.person_outline_rounded,
                size: 58,
                color: AppColors.primary,
              ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> data) {
    final isApproved = _isApproved(data);
    final isBlocked = _isBlocked(data);

    final statusLabel = isBlocked
        ? 'مسدود شده'
        : (isApproved ? 'تأیید شده' : 'در انتظار تأیید');

    final statusColor = isBlocked
        ? Colors.red
        : (isApproved ? Colors.green : Colors.orange.shade800);

    final statusIcon = isBlocked
        ? Icons.block_rounded
        : (isApproved
            ? Icons.verified_rounded
            : Icons.pending_actions_rounded);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'وضعیت حساب راننده',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBlocked
                      ? 'این راننده امکان استفاده از سیستم را ندارد.'
                      : (isApproved
                          ? 'مدارک این راننده توسط مدیریت تأیید شده است.'
                          : 'مدارک راننده هنوز نیاز به بررسی و تأیید دارند.'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityDocuments(Map<String, dynamic> data) {
    final documents = [
      _DocumentItem(
        title: _safeTranslation('id_front', fallback: 'روی کارت هویت'),
        icon: Icons.credit_card_outlined,
        url: _readNullableText(
          data,
          [
            'cnicFrontImage',
            'idCardUrl',
            'id_card_url',
            'identityCardFrontUrl',
            'identity_card_front_url',
          ],
        ),
      ),
      _DocumentItem(
        title: _safeTranslation('id_back', fallback: 'پشت کارت هویت'),
        icon: Icons.credit_card_outlined,
        url: _readNullableText(
          data,
          [
            'cnicBackImage',
            'idCardBackUrl',
            'id_card_back_url',
            'identityCardBackUrl',
            'identity_card_back_url',
          ],
        ),
      ),
      _DocumentItem(
        title: _safeTranslation(
          'selfie_with_id',
          fallback: 'عکس راننده با کارت هویت',
        ),
        icon: Icons.face_retouching_natural_outlined,
        url: _readNullableText(
          data,
          [
            'driverFaceWithCnic',
            'selfieWithIdUrl',
            'selfie_with_id_url',
            'identitySelfieUrl',
          ],
        ),
      ),
    ];

    return _buildDocumentsGrid(documents);
  }

  Widget _buildLicenseSection(Map<String, dynamic> data) {
    final licenseNumber = _readText(
      data,
      [
        'drivingLicenseNumber',
        'licenseNumber',
        'license_number',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final documents = [
      _DocumentItem(
        title: _safeTranslation(
          'license_front',
          fallback: 'روی گواهینامه',
        ),
        icon: Icons.badge_outlined,
        url: _readNullableText(
          data,
          [
            'drivingLicenseFrontImage',
            'licenseUrl',
            'license_url',
            'licenseFrontUrl',
            'license_front_url',
          ],
        ),
      ),
      _DocumentItem(
        title: _safeTranslation(
          'license_back',
          fallback: 'پشت گواهینامه',
        ),
        icon: Icons.badge_outlined,
        url: _readNullableText(
          data,
          [
            'drivingLicenseBackImage',
            'licenseBackUrl',
            'license_back_url',
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem(
          icon: Icons.numbers_rounded,
          label: _safeTranslation(
            'license_number',
            fallback: 'شماره گواهینامه',
          ),
          value: licenseNumber,
        ),
        const SizedBox(height: 16),
        _buildDocumentsGrid(documents),
      ],
    );
  }

  Widget _buildVehicleSection(Map<String, dynamic> data) {
    final vehicleData = _readVehicleData(data);

    final isVehicleEmpty = vehicleData.isEmpty &&
        _readText(
          data,
          [
            'carModel',
            'car_model',
            'carColor',
            'car_color',
          ],
        ).isEmpty;

    if (isVehicleEmpty) {
      return Text(
        _safeTranslation(
          'vehicle_not_registered',
          fallback: 'اطلاعات خودرو ثبت نشده است.',
        ),
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
      );
    }

    final type = _readTextFromMaps(
      [vehicleData, data],
      [
        'type',
        'vehicleType',
        'vehicle_type',
        'carType',
        'car_type',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final brand = _readTextFromMaps(
      [vehicleData, data],
      [
        'brand',
        'carBrand',
        'car_brand',
        'make',
        'carModel',
        'car_model',
        'model',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final color = _readTextFromMaps(
      [vehicleData, data],
      [
        'color',
        'carColor',
        'car_color',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final year = _readTextFromMaps(
      [vehicleData, data],
      [
        'productionYear',
        'production_year',
        'year',
        'carYear',
        'car_year',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final plate = _readTextFromMaps(
      [vehicleData, data],
      [
        'registrationPlateNumber',
        'plateNumber',
        'plate_number',
        'carPlate',
        'car_plate',
      ],
      fallback: _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      ),
    );

    final documents = [
      _DocumentItem(
        title: _safeTranslation(
          'car_card_front',
          fallback: 'روی کارت خودرو',
        ),
        icon: Icons.description_outlined,
        url: _readNullableTextFromMaps(
          [vehicleData, data],
          [
            'registrationCertificateFrontImage',
            'carCardFrontUrl',
            'car_card_front_url',
          ],
        ),
      ),
      _DocumentItem(
        title: _safeTranslation(
          'car_card_back',
          fallback: 'پشت کارت خودرو',
        ),
        icon: Icons.description_outlined,
        url: _readNullableTextFromMaps(
          [vehicleData, data],
          [
            'registrationCertificateBackImage',
            'carCardBackUrl',
            'car_card_back_url',
          ],
        ),
      ),
      _DocumentItem(
        title: 'عکس خودرو',
        icon: Icons.directions_car_outlined,
        url: _readNullableTextFromMaps(
          [vehicleData, data],
          [
            'carPhotoUrl',
            'car_photo_url',
            'vehiclePhotoUrl',
            'vehicle_photo_url',
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            _buildInfoItem(
              icon: Icons.directions_car_outlined,
              label: _safeTranslation(
                'vehicle_type',
                fallback: 'نوع خودرو',
              ),
              value: type,
            ),
            _buildInfoItem(
              icon: Icons.branding_watermark_outlined,
              label: _safeTranslation(
                'vehicle_brand',
                fallback: 'برند / مدل',
              ),
              value: brand,
            ),
            _buildInfoItem(
              icon: Icons.palette_outlined,
              label: _safeTranslation(
                'vehicle_color',
                fallback: 'رنگ خودرو',
              ),
              value: color,
            ),
            _buildInfoItem(
              icon: Icons.calendar_today_outlined,
              label: _safeTranslation(
                'production_year',
                fallback: 'سال ساخت',
              ),
              value: year,
            ),
            _buildInfoItem(
              icon: Icons.pin_outlined,
              label: _safeTranslation(
                'plate_number',
                fallback: 'شماره پلاک',
              ),
              value: plate,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildDocumentsGrid(documents),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'inherit',
                  fontSize: 12,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsGrid(List<_DocumentItem> documents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns = 1;

        if (width >= 850) {
          columns = 3;
        } else if (width >= 520) {
          columns = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 1.65 : 1.15,
          ),
          itemBuilder: (context, index) {
            return _buildDocumentCard(documents[index]);
          },
        );
      },
    );
  }

  Widget _buildDocumentCard(_DocumentItem document) {
    final hasUrl =
        document.url != null && document.url!.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: hasUrl
          ? () {
              _showFullImageDialog(
                title: document.title,
                imageUrl: document.url!,
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.11),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: hasUrl
                    ? Image.network(
                        document.url!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder(
                            icon: Icons.broken_image_outlined,
                            label: 'تصویر قابل نمایش نیست',
                          );
                        },
                      )
                    : _buildImagePlaceholder(
                        icon: Icons.image_not_supported_outlined,
                        label: 'تصویر ثبت نشده است',
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    document.icon,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasUrl)
                    const Icon(
                      Icons.zoom_in_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 38,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImageDialog({
    required String title,
    required String imageUrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: Stack(
            children: [
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                  maxHeight: 720,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'بستن',
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.6,
                        maxScale: 4,
                        child: Center(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;

                              return const CircularProgressIndicator(
                                color: AppColors.primary,
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(
                                icon: Icons.broken_image_outlined,
                                label: 'تصویر قابل نمایش نیست',
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.grey.shade100,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  String _driverName(Map<String, dynamic> data) {
    final directName = _readText(
      data,
      [
        'name',
        'driverName',
        'driver_name',
        'fullName',
        'full_name',
      ],
    );

    if (directName.isNotEmpty) {
      return directName;
    }

    final firstName = _readText(
      data,
      [
        'firstName',
        'first_name',
      ],
    );

    final secondName = _readText(
      data,
      [
        'secondName',
        'lastName',
        'last_name',
        'familyName',
      ],
    );

    final fullName = '$firstName $secondName'.trim();

    return fullName.isEmpty
        ? _safeTranslation('unknown', fallback: 'راننده ناشناس')
        : fullName;
  }

  bool _isApproved(Map<String, dynamic> data) {
    final value = data['isApproved'] ?? data['status'];

    return value == true ||
        value.toString().trim().toLowerCase() == 'approved';
  }

  bool _isBlocked(Map<String, dynamic> data) {
    final value = data['isBlocked'] ??
        data['blockStatus'] ??
        data['status'];

    final normalized = value.toString().trim().toLowerCase();

    return value == true ||
        normalized == 'yes' ||
        normalized == 'blocked';
  }

  Map<String, dynamic> _readVehicleData(
    Map<String, dynamic> data,
  ) {
    final vehicle = data['vehicleInfo'] ??
        data['vehicle_info'] ??
        data['carDetails'] ??
        data['car_details'];

    if (vehicle is Map) {
      return Map<String, dynamic>.from(vehicle);
    }

    return {};
  }

  String _readTextFromMaps(
    List<Map<String, dynamic>> sources,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final source in sources) {
      final value = _readText(source, keys);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  String? _readNullableTextFromMaps(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    final value = _readTextFromMaps(sources, keys);

    return value.isEmpty ? null : value;
  }

  String _readText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString();
      }

      if (value is Map) {
        final nestedValue = _readMapText(
          value,
          [
            'name',
            'title',
            'value',
            'text',
            'model',
          ],
        );

        if (nestedValue.isNotEmpty) {
          return nestedValue;
        }
      }
    }

    return fallback;
  }

  String? _readNullableText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final value = _readText(data, keys);

    return value.isEmpty ? null : value;
  }

  dynamic _readValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  String _readMapText(
    Map<dynamic, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return _safeTranslation(
        'not_registered',
        fallback: 'ثبت نشده',
      );
    }

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return value.toString();
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
  }

  String _safeTranslation(
    String key, {
    required String fallback,
  }) {
    final translated = key.tr();

    return translated == key ? fallback : translated;
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(34),
        constraints: const BoxConstraints(maxWidth: 450),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 46,
            ),
            const SizedBox(height: 14),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentItem {
  final String title;
  final IconData icon;
  final String? url;

  const _DocumentItem({
    required this.title,
    required this.icon,
    required this.url,
  });
}
