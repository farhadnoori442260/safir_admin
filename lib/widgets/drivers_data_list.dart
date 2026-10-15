import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class DriversDataList extends StatefulWidget {
  final String searchQuery;
  final String filterStatus;
  final String role;
  final Map<String, dynamic> permissions;

  const DriversDataList({
    super.key,
    this.searchQuery = '',
    this.filterStatus = 'all',
    this.role = 'superAdmin',
    this.permissions = const {},
  });

  @override
  State<DriversDataList> createState() => _DriversDataListState();
}

class _DriversDataListState extends State<DriversDataList> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream =
      FirebaseFirestore.instance.collection('drivers').snapshots();

  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _driversStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStateMessage(
            icon: Icons.error_outline_rounded,
            message: 'خطا در خواندن رانندگان: ${snapshot.error}',
            color: Colors.red.shade600,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(42),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _buildStateMessage(
            icon: Icons.people_outline_rounded,
            message: 'هیچ راننده‌ای ثبت نشده است',
            color: Colors.grey.shade500,
          );
        }

        final filteredDocuments = documents.where(_matchesFilter).toList();

        if (filteredDocuments.isEmpty) {
          return _buildStateMessage(
            icon: Icons.search_off_rounded,
            message: 'نتیجه‌ای با این مشخصات یافت نشد',
            color: Colors.grey.shade500,
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: filteredDocuments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _buildDriverRow(
              context,
              filteredDocuments[index],
            );
          },
        );
      },
    );
  }

  bool _matchesFilter(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final name = _driverName(data).toLowerCase();
    final phone = _firstText(data, [
      'phoneNumber',
      'phone',
      'phone_number',
      'mobile',
    ]).toLowerCase();

    final email = _firstText(data, [
      'email',
      'emailAddress',
    ]).toLowerCase();

    final query = widget.searchQuery.trim().toLowerCase();

    final matchesSearch = query.isEmpty ||
        name.contains(query) ||
        phone.contains(query) ||
        email.contains(query) ||
        document.id.toLowerCase().contains(query);

    final status = _driverStatus(data);

    bool matchesStatus;

    switch (widget.filterStatus) {
      case 'pending':
        matchesStatus = status == _DriverStatus.pending;
        break;
      case 'approved':
        matchesStatus = status == _DriverStatus.approved;
        break;
      case 'blocked':
        matchesStatus = status == _DriverStatus.blocked;
        break;
      case 'all':
      default:
        matchesStatus = true;
    }

    return matchesSearch && matchesStatus;
  }

  Widget _buildDriverRow(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final driverName = _driverName(
      data,
      fallback: 'راننده ناشناس',
    );

    final phone = _firstText(
      data,
      [
        'phoneNumber',
        'phone',
        'phone_number',
        'mobile',
      ],
      fallback: '-',
    );

    final vehicleInfo = _vehicleInfo(data);

    final vehicleType = _vehicleTypeLabel(
      _firstTextFromMap(vehicleInfo, ['type']),
    );

    final vehicleBrand = _firstTextFromMap(
      vehicleInfo,
      [
        'brand',
        'model',
        'carModel',
      ],
    );

    final vehicleColor = _firstTextFromMap(
      vehicleInfo,
      [
        'color',
        'carColor',
      ],
    );

    final plate = _buildPlateText(vehicleInfo);

    final vehicleDetails = <String>[
      if (vehicleType.isNotEmpty) vehicleType,
      if (vehicleBrand.isNotEmpty) vehicleBrand,
      if (vehicleColor.isNotEmpty) vehicleColor,
      if (plate.isNotEmpty) plate,
    ].join(' • ');

    final status = _driverStatus(data);

    final profileImageUrl = _firstNullableText(
      data,
      [
        'profilePicture',
        'profileImage',
        'profileImageUrl',
        'photo',
        'photoUrl',
        'photo_url',
        'imageUrl',
      ],
    );

    final vehicleImageUrl = _firstNullableTextFromMap(
      vehicleInfo,
      [
        'vehiclePicture',
        'vehicleImage',
        'vehicleImageUrl',
        'carPhotoUrl',
        'car_photo_url',
      ],
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: Row(
          children: [
            _dataCell(
              flex: 8,
              child: _buildDriverCode(document.id),
            ),
            _dataCell(
              flex: 17,
              child: _buildDriverIdentity(
                name: driverName,
                photoUrl: profileImageUrl,
              ),
            ),
            _dataCell(
              flex: 13,
              child: _buildSimpleText(
                phone,
                icon: Icons.phone_outlined,
              ),
            ),
            _dataCell(
              flex: 16,
              child: _buildVehicleCell(
                type: vehicleType,
                details: vehicleDetails,
                vehicleImageUrl: vehicleImageUrl,
              ),
            ),
            _dataCell(
              flex: 12,
              child: _buildStatusChip(status),
            ),
            _dataCell(
              flex: 11,
              child: IconButton(
                tooltip: 'مشاهده مدارک',
                icon: const Icon(
                  Icons.folder_shared_outlined,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  _showDocumentsDialog(
                    context: context,
                    data: data,
                    driverName: driverName,
                  );
                },
              ),
            ),
            _dataCell(
              flex: 20,
              child: _buildActions(
                context: context,
                document: document,
                status: status,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell({
    required int flex,
    required Widget child,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: child,
      ),
    );
  }

  Widget _buildDriverCode(String id) {
    final shortId = id.length > 6 ? id.substring(0, 6) : id;

    return Tooltip(
      message: id,
      child: Text(
        shortId,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDriverIdentity({
    required String name,
    required String? photoUrl,
  }) {
    return Row(
      children: [
        _buildAvatar(photoUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.09),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 21,
                  );
                },
              )
            : const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
                size: 21,
              ),
      ),
    );
  }

  Widget _buildVehicleCell({
    required String type,
    required String details,
    required String? vehicleImageUrl,
  }) {
    return Row(
      children: [
        _buildVehicleAvatar(vehicleImageUrl, type),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            details.isEmpty ? 'وسیلهٔ نقلیه' : details,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleAvatar(
    String? imageUrl,
    String vehicleType,
  ) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.network(
          imageUrl!,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _vehicleIconBox(vehicleType);
          },
        ),
      );
    }

    return _vehicleIconBox(vehicleType);
  }

  Widget _vehicleIconBox(String vehicleType) {
    IconData icon;

    switch (vehicleType) {
      case 'موترسایکل':
        icon = Icons.two_wheeler_rounded;
        break;
      case 'باربری':
        icon = Icons.local_shipping_rounded;
        break;
      default:
        icon = Icons.local_taxi_rounded;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        color: AppColors.primary,
        size: 23,
      ),
    );
  }

  Widget _buildSimpleText(
    String value, {
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(_DriverStatus status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _statusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required _DriverStatus status,
  }) {
    final isApproved = status == _DriverStatus.approved;
    final isBlocked = status == _DriverStatus.blocked;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ElevatedButton.icon(
            onPressed: _isUpdating
                ? null
                : () {
                    _confirmApprovalChange(
                      context: context,
                      document: document,
                      currentlyApproved: isApproved,
                    );
                  },
            icon: Icon(
              isApproved
                  ? Icons.remove_moderator_outlined
                  : Icons.verified_outlined,
              size: 15,
            ),
            label: Text(
              isApproved ? 'لغو تأیید' : 'تأیید',
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproved ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 9,
              ),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: isBlocked ? 'خروج از مسدودی' : 'مسدود کردن راننده',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isUpdating
                ? null
                : () {
                    _confirmBlockChange(
                      context: context,
                      document: document,
                      currentlyBlocked: isBlocked,
                    );
                  },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isBlocked
                    ? Colors.green.withOpacity(0.10)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                color: isBlocked ? Colors.green : Colors.red,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmApprovalChange({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required bool currentlyApproved,
  }) async {
    final action = currentlyApproved ? 'لغو تأیید' : 'تأیید';

    final confirmed = await _showConfirmDialog(
      context: context,
      title: '$action مدارک',
      message: currentlyApproved
          ? 'آیا می‌خواهید تأیید مدارک این راننده لغو شود؟'
          : 'آیا مدارک این راننده را تأیید می‌کنید؟',
      confirmText: action,
      color: currentlyApproved ? Colors.orange : Colors.green,
    );

    if (confirmed == true) {
      await _updateDriverApproval(
        driverId: document.id,
        currentApproved: currentlyApproved,
      );
    }
  }

  Future<void> _confirmBlockChange({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required bool currentlyBlocked,
  }) async {
    final action = currentlyBlocked ? 'خروج از مسدودی' : 'مسدود کردن';

    final confirmed = await _showConfirmDialog(
      context: context,
      title: action,
      message: currentlyBlocked
          ? 'آیا می‌خواهید این راننده از حالت مسدود خارج شود؟'
          : 'آیا مطمئن هستید که می‌خواهید این راننده را مسدود کنید؟',
      confirmText: action,
      color: currentlyBlocked ? Colors.green : Colors.red,
    );

    if (confirmed == true) {
      await _updateDriverBlockStatus(
        driverId: document.id,
        currentlyBlocked: currentlyBlocked,
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required Color color,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'انصراف',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDriverApproval({
    required String driverId,
    required bool currentApproved,
  }) async {
    if (_isUpdating) return;

    final newApproved = !currentApproved;

    setState(() {
      _isUpdating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'isApproved': newApproved,
        'status': newApproved ? 'approved' : 'pending',
        'newDriverStatus': newApproved ? 'approved' : 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar(
        newApproved
            ? 'مدارک راننده با موفقیت تأیید شد'
            : 'تأیید مدارک راننده لغو شد',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در به‌روزرسانی راننده: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateDriverBlockStatus({
    required String driverId,
    required bool currentlyBlocked,
  }) async {
    if (_isUpdating) return;

    final newBlocked = !currentlyBlocked;

    setState(() {
      _isUpdating = true;
    });

    try {
      final reference =
          FirebaseFirestore.instance.collection('drivers').doc(driverId);

      final currentDocument = await reference.get();
      final currentData = currentDocument.data() ?? {};
      final currentApproved = _isApproved(currentData);

      await reference.update({
        'isBlocked': newBlocked,
        'blockStatus': newBlocked ? 'yes' : 'no',
        'status':
            newBlocked ? 'blocked' : (currentApproved ? 'approved' : 'pending'),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar(
        newBlocked ? 'راننده با موفقیت مسدود شد' : 'راننده از حالت مسدود خارج شد',
        newBlocked ? Colors.red : Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در تغییر وضعیت مسدودی: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showDocumentsDialog({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String driverName,
  }) {
    final documents = _collectDocuments(data);

    if (documents.isEmpty) {
      _showSnackBar(
        'هیچ تصویری برای مدارک این راننده ثبت نشده است.',
        Colors.orange,
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
              maxHeight: 720,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.folder_shared_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'مدارک راننده: $driverName',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: documents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = documents[index];

                        return _buildDocumentCard(
                          title: item.title,
                          url: item.url,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String url,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Image.network(
              url,
              width: double.infinity,
              height: 245,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;

                return const SizedBox(
                  height: 245,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 245,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 42,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'تصویر قابل نمایش نیست',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_DriverDocument> _collectDocuments(
    Map<String, dynamic> data,
  ) {
    final documents = <_DriverDocument>[];
    final vehicleInfo = _vehicleInfo(data);

    _addDocument(
      documents,
      _firstNullableText(
        data,
        [
          'profilePicture',
          'profileImage',
          'profileImageUrl',
          'photo',
          'photoUrl',
          'photo_url',
          'imageUrl',
        ],
      ),
      'عکس پروفایل راننده',
    );

    _addDocument(
      documents,
      _firstNullableText(
        data,
        [
          'cnicFrontImage',
          'cnicFrontImageUrl',
          'idCardFrontImage',
          'identityCardFrontImage',
          'idCardUrl',
        ],
      ),
      'روی کارت هویت',
    );

    _addDocument(
      documents,
      _firstNullableText(
        data,
        [
          'cnicBackImage',
          'cnicBackImageUrl',
          'idCardBackImage',
          'identityCardBackImage',
        ],
      ),
      'پشت کارت هویت',
    );

    _addDocument(
      documents,
      _firstNullableText(
        data,
        [
          'driverFaceWithCnic',
          'driverFaceWithCnicImage',
          'cnicWithSelfieImage',
          'selfieWithCnic',
        ],
      ),
      'عکس سلفی با کارت هویت',
    );

    _addDocument(
      documents,
      _firstNullableText(
        data,
        [
          'drivingLicenseFrontImage',
          'drivingLicenseFrontImageUrl',
          'licenseFrontImage',
          'drivingLicenseUrl',
          'licenseUrl',
        ],
      ),
      'روی گواهینامه',
    );

    _addDocument(
      documents,
      _firstNullableText(
        data,
        [
          'drivingLicenseBackImage',
          'drivingLicenseBackImageUrl',
          'licenseBackImage',
        ],
      ),
      'پشت گواهینامه',
    );

    _addDocument(
      documents,
      _firstNullableTextFromMap(
        vehicleInfo,
        [
          'vehiclePicture',
          'vehicleImage',
          'vehicleImageUrl',
          'carPhotoUrl',
          'car_photo_url',
        ],
      ),
      'عکس وسیلهٔ نقلیه',
    );

    _addDocument(
      documents,
      _firstNullableTextFromMap(
        vehicleInfo,
        [
          'registrationCertificateFrontImage',
          'vehicleRegistrationFrontImage',
          'registrationFrontImage',
          'vehicleRegistrationFrontImageUrl',
        ],
      ),
      'روی سند وسیلهٔ نقلیه',
    );

    _addDocument(
      documents,
      _firstNullableTextFromMap(
        vehicleInfo,
        [
          'registrationCertificateBackImage',
          'vehicleRegistrationBackImage',
          'registrationBackImage',
          'vehicleRegistrationBackImageUrl',
        ],
      ),
      'پشت سند وسیلهٔ نقلیه',
    );

    final uniqueUrls = <String>{};

    return documents.where((document) {
      return uniqueUrls.add(document.url);
    }).toList();
  }

  void _addDocument(
    List<_DriverDocument> documents,
    String? url,
    String title,
  ) {
    if (url == null || url.trim().isEmpty) return;

    documents.add(
      _DriverDocument(
        title: title,
        url: url.trim(),
      ),
    );
  }

  Map<String, dynamic> _vehicleInfo(
    Map<String, dynamic> data,
  ) {
    final value = data['vehicleInfo'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _driverName(
    Map<String, dynamic> data, {
    String fallback = '',
  }) {
    final firstName = _firstText(
      data,
      [
        'firstName',
        'firstname',
        'first_name',
      ],
    );

    final secondName = _firstText(
      data,
      [
        'secondName',
        'lastName',
        'lastname',
        'last_name',
        'surname',
      ],
    );

    final combined = '$firstName $secondName'.trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    return _firstText(
      data,
      [
        'name',
        'driver_name',
        'driverName',
        'fullName',
        'fullname',
        'username',
      ],
      fallback: fallback,
    );
  }

  String _buildPlateText(
    Map<String, dynamic> vehicleInfo,
  ) {
    final province = _firstTextFromMap(
      vehicleInfo,
      ['plateProvince'],
    );

    final category = _firstTextFromMap(
      vehicleInfo,
      ['plateCategory'],
    );

    final plateType = _firstTextFromMap(
      vehicleInfo,
      ['plateType'],
    );

    final number = _firstTextFromMap(
      vehicleInfo,
      [
        'registrationPlateNumber',
        'plateNumber',
        'carNumber',
      ],
    );

    final parts = <String>[
      if (province.isNotEmpty) province,
      if (category.isNotEmpty) category,
      if (number.isNotEmpty) number,
    ];

    if (parts.isEmpty) {
      return '';
    }

    final result = parts.join(' - ');

    if (plateType.isNotEmpty) {
      return '$result ($plateType)';
    }

    return result;
  }

  String _vehicleTypeLabel(String rawType) {
    final value = rawType.trim().toLowerCase();

    if (value.isEmpty) {
      return 'وسیلهٔ نقلیه';
    }

    if (value == 'bike' ||
        value == 'motorbike' ||
        value == 'motorcycle' ||
        value == 'موترسایکل' ||
        value == 'موتورسیکلت') {
      return 'موترسایکل';
    }

    if (value == 'cargo' ||
        value == 'truck' ||
        value == 'freight' ||
        value == 'باربری') {
      return 'باربری';
    }

    if (value == 'car' ||
        value == 'taxi' ||
        value == 'auto' ||
        value == 'موتر' ||
        value == 'تاکسی') {
      return 'تاکسی';
    }

    return rawType.trim();
  }

  String _firstText(
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
    }

    return fallback;
  }

  String _firstTextFromMap(
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
    }

    return fallback;
  }

  String? _firstNullableText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final value = _firstText(data, keys);
    return value.isEmpty ? null : value;
  }

  String? _firstNullableTextFromMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final value = _firstTextFromMap(data, keys);
    return value.isEmpty ? null : value;
  }

  _DriverStatus _driverStatus(
    Map<String, dynamic> data,
  ) {
    if (_isBlocked(data)) {
      return _DriverStatus.blocked;
    }

    if (_isApproved(data)) {
      return _DriverStatus.approved;
    }

    return _DriverStatus.pending;
  }

  bool _isApproved(
    Map<String, dynamic> data,
  ) {
    final value = data['isApproved'];

    if (value == true) return true;

    final text = value?.toString().trim().toLowerCase();

    if (text == 'true' || text == 'approved' || text == 'yes') {
      return true;
    }

    final status = data['status']?.toString().trim().toLowerCase();

    return status == 'approved';
  }

  bool _isBlocked(
    Map<String, dynamic> data,
  ) {
    final value = data['isBlocked'];

    if (value == true) return true;

    final blockStatus = data['blockStatus']?.toString().trim().toLowerCase();

    final status = data['status']?.toString().trim().toLowerCase();

    return blockStatus == 'yes' ||
        blockStatus == 'blocked' ||
        status == 'blocked';
  }

  Color _statusColor(
    _DriverStatus status,
  ) {
    switch (status) {
      case _DriverStatus.approved:
        return Colors.green;
      case _DriverStatus.blocked:
        return Colors.red;
      case _DriverStatus.pending:
        return Colors.orange;
    }
  }

  String _statusLabel(
    _DriverStatus status,
  ) {
    switch (status) {
      case _DriverStatus.approved:
        return 'تأیید شده';
      case _DriverStatus.blocked:
        return 'مسدود شده';
      case _DriverStatus.pending:
        return 'در انتظار';
    }
  }

  IconData _statusIcon(
    _DriverStatus status,
  ) {
    switch (status) {
      case _DriverStatus.approved:
        return Icons.verified_rounded;
      case _DriverStatus.blocked:
        return Icons.block_rounded;
      case _DriverStatus.pending:
        return Icons.pending_actions_rounded;
    }
  }

  void _showSnackBar(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 44,
            color: color,
          ),
          const SizedBox(height: 13),
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
    );
  }
}

enum _DriverStatus {
  pending,
  approved,
  blocked,
}

class _DriverDocument {
  final String title;
  final String url;

  const _DriverDocument({
    required this.title,
    required this.url,
  });
}
