import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/permissions.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

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

enum _Status { pending, approved, blocked }

class _Doc {
  final String title;
  final String url;
  const _Doc(this.title, this.url);
}

const _phoneKeys = ['phoneNumber', 'phone', 'phone_number', 'mobile'];
const _photoKeys = [
  'profilePicture',
  'profileImage',
  'profileImageUrl',
  'photo',
  'photoUrl',
  'photo_url',
  'imageUrl',
];
const _vehiclePhotoKeys = [
  'vehiclePicture',
  'vehicleImage',
  'vehicleImageUrl',
  'carPhotoUrl',
  'car_photo_url',
];

class _DriversDataListState extends State<DriversDataList> {
  // حداکثر ۵۰۰ راننده؛ برای دادهٔ بزرگ‌تر باید جستجوی سمت سرور اضافه شود.
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('drivers').limit(500).snapshots();

  bool _isUpdating = false;

  bool _can(String key, [List<String> alt = const []]) => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: 'drivers',
        key: key,
        alternatives: alt,
      );

  bool get _canView => _can('view');
  bool get _canViewDocs =>
      _can('viewDocuments', const ['documents', 'view_documents']);
  bool get _canUpdate => _can('update', const ['edit', 'changeStatus']);
  bool get _canBlock => _can('delete', const ['block', 'blockDriver']);

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return AdminStateMessage(
        icon: Icons.lock_outline_rounded,
        message: 'شما اجازهٔ مشاهدهٔ فهرست رانندگان را ندارید.',
        color: AppColors.danger,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminStateMessage(
            icon: Icons.error_outline_rounded,
            message: 'خطا در خواندن رانندگان:\n${snapshot.error}',
            color: AppColors.danger,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminLoading();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const AdminStateMessage(
            icon: Icons.people_outline_rounded,
            message: 'هیچ راننده‌ای ثبت نشده است',
          );
        }

        final filtered = docs.where(_matches).toList();
        if (filtered.isEmpty) {
          return const AdminStateMessage(
            icon: Icons.search_off_rounded,
            message: 'نتیجه‌ای با این مشخصات یافت نشد',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _row(context, filtered[i]),
        );
      },
    );
  }

  bool _matches(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final q = widget.searchQuery.trim().toLowerCase();

    final okSearch = q.isEmpty ||
        _name(d).toLowerCase().contains(q) ||
        _pick(d, _phoneKeys).toLowerCase().contains(q) ||
        _pick(d, const ['email', 'emailAddress']).toLowerCase().contains(q) ||
        doc.id.toLowerCase().contains(q);

    final s = _status(d);
    final okStatus = widget.filterStatus == 'pending'
        ? s == _Status.pending
        : widget.filterStatus == 'approved'
            ? s == _Status.approved
            : widget.filterStatus == 'blocked'
                ? s == _Status.blocked
                : true;

    return okSearch && okStatus;
  }

  // ───────── ردیف ─────────
  Widget _row(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final v = _vehicle(d);
    final name = _name(d, fallback: 'راننده ناشناس');
    final phone = _pick(d, _phoneKeys, fallback: '-');
    final type = _typeLabel(_pick(v, const ['type', 'vehicleType', 'carType']));
    final brand = _pick(v, const ['brand', 'model', 'carModel', 'vehicleBrand']);
    final color = _pick(v, const ['color', 'carColor', 'vehicleColor']);
    final plate = _plate(v);

    final details = [
      if (type.isNotEmpty) type,
      if (brand.isNotEmpty) brand,
      if (color.isNotEmpty) color,
      if (plate.isNotEmpty) plate,
    ].join(' • ');

    final status = _status(d);
    final photo = _pick(d, _photoKeys);
    final vPhoto = _pick(v, _vehiclePhotoKeys);

    return AdminCard(
      minHeight: 82,
      child: Row(
        children: [
          _cell(8, _code(doc.id)),
          _cell(
            17,
            Row(
              children: [
                AdminAvatar(url: photo.isEmpty ? null : photo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _cell(
            13,
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phone,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _cell(
            16,
            Row(
              children: [
                AdminAvatar(
                  url: vPhoto.isEmpty ? null : vPhoto,
                  icon: _vehicleIcon(type),
                  size: 42,
                  round: false,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    details.isEmpty ? 'وسیلهٔ نقلیه' : details,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _cell(
            12,
            AdminChip(
              label: _statusLabel(status),
              icon: _statusIcon(status),
              color: _statusColor(status),
            ),
          ),
          _cell(11, _docsButton(context, d, name)),
          _cell(20, _actions(context, doc, status)),
        ],
      ),
    );
  }

  Widget _cell(int flex, Widget child) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: child,
        ),
      );

  Widget _code(String id) {
    final short = id.length > 6 ? id.substring(0, 6) : id;
    return Tooltip(
      message: id,
      child: Text(
        short,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.brand,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _docsButton(
    BuildContext context,
    Map<String, dynamic> data,
    String name,
  ) {
    if (!_canViewDocs) {
      return Tooltip(
        message: 'مجوز مشاهدهٔ مدارک را ندارید',
        child: Icon(Icons.lock_outline_rounded,
            color: AppColors.textMuted, size: 20),
      );
    }
    return IconButton(
      tooltip: 'مشاهدهٔ مدارک',
      icon: Icon(Icons.folder_shared_outlined, color: AppColors.brand),
      onPressed: () => _showDocuments(context, data, name),
    );
  }

  Widget _actions(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    _Status status,
  ) {
    final approved = status == _Status.approved;
    final blocked = status == _Status.blocked;

    if (!_canUpdate && !_canBlock) {
      return Tooltip(
        message: 'مجوز انجام عملیات را ندارید',
        child: Icon(Icons.lock_outline_rounded,
            color: AppColors.textMuted, size: 20),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canUpdate)
          Flexible(
            child: ElevatedButton.icon(
              onPressed:
                  _isUpdating ? null : () => _confirmApproval(context, doc, approved),
              icon: Icon(
                approved
                    ? Icons.remove_moderator_outlined
                    : Icons.verified_outlined,
                size: 15,
              ),
              label: Text(
                approved ? 'لغو تأیید' : 'تأیید',
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    approved ? AppColors.warning : AppColors.accentButton,
                foregroundColor: AppColors.isDark && approved
                    ? Colors.black
                    : AppColors.buttonText,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        if (_canUpdate && _canBlock) const SizedBox(width: 6),
        if (_canBlock)
          AdminIconAction(
            icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
            color: blocked ? AppColors.ok : AppColors.danger,
            tooltip: blocked ? 'خروج از مسدودی' : 'مسدود کردن راننده',
            onTap: _isUpdating ? null : () => _confirmBlock(context, doc, blocked),
          ),
      ],
    );
  }

  // ───────── تأیید / مسدودی ─────────
  Future<void> _confirmApproval(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool approved,
  ) async {
    if (!_canUpdate) return;
    final action = approved ? 'لغو تأیید' : 'تأیید';

    final ok = await showAdminConfirm(
      context: context,
      title: '$action مدارک',
      message: approved
          ? 'آیا می‌خواهید تأیید مدارک این راننده لغو شود؟'
          : 'آیا مدارک این راننده را تأیید می‌کنید؟',
      confirmText: action,
      color: approved ? AppColors.warning : AppColors.accentButton,
    );
    if (ok == true) await _setApproval(doc.id, !approved);
  }

  Future<void> _confirmBlock(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool blocked,
  ) async {
    if (!_canBlock) return;
    final action = blocked ? 'خروج از مسدودی' : 'مسدود کردن';

    final ok = await showAdminConfirm(
      context: context,
      title: action,
      message: blocked
          ? 'آیا می‌خواهید این راننده از حالت مسدود خارج شود؟'
          : 'آیا مطمئن هستید که می‌خواهید این راننده را مسدود کنید؟',
      confirmText: action,
      color: blocked ? AppColors.accentButton : AppColors.danger,
    );
    if (ok == true) await _setBlocked(doc.id, !blocked);
  }

  Future<void> _setApproval(String id, bool approve) async {
    if (!_canUpdate || _isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance.collection('drivers').doc(id).update({
        'isApproved': approve,
        'status': approve ? 'approved' : 'pending',
        'newDriverStatus': approve ? 'approved' : 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AdminLog.write(
        action: approve ? 'driver_approved' : 'driver_approval_revoked',
        targetType: 'driver',
        targetId: id,
      );

      if (!mounted) return;
      showAdminSnack(
        context,
        approve ? 'مدارک راننده تأیید شد' : 'تأیید مدارک راننده لغو شد',
        tone: approve ? AdminTone.ok : AdminTone.warning,
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در به‌روزرسانی راننده: ${e.message ?? e.code}',
            tone: AdminTone.error);
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در به‌روزرسانی راننده: $e',
            tone: AdminTone.error);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _setBlocked(String id, bool block) async {
    if (!_canBlock || _isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final ref = FirebaseFirestore.instance.collection('drivers').doc(id);
      final current = (await ref.get()).data() ?? {};
      final approved = _isApproved(current);

      await ref.update({
        'isBlocked': block,
        'blockStatus': block ? 'yes' : 'no',
        'status': block ? 'blocked' : (approved ? 'approved' : 'pending'),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AdminLog.write(
        action: block ? 'driver_blocked' : 'driver_unblocked',
        targetType: 'driver',
        targetId: id,
      );

      if (!mounted) return;
      showAdminSnack(
        context,
        block ? 'راننده مسدود شد' : 'راننده از حالت مسدود خارج شد',
        tone: block ? AdminTone.warning : AdminTone.ok,
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        showAdminSnack(
            context, 'خطا در تغییر وضعیت مسدودی: ${e.message ?? e.code}',
            tone: AdminTone.error);
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در تغییر وضعیت مسدودی: $e',
            tone: AdminTone.error);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ───────── مدارک ─────────
  void _showDocuments(
    BuildContext context,
    Map<String, dynamic> data,
    String name,
  ) {
    if (!_canViewDocs) return;

    final docs = _collectDocs(data);
    if (docs.isEmpty) {
      showAdminSnack(context, 'هیچ تصویری برای مدارک این راننده ثبت نشده است.',
          tone: AdminTone.warning);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.folder_shared_rounded,
                          color: AppColors.brand),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'مدارک راننده: $name',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _docCard(docs[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _docCard(_Doc doc) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              doc.title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Image.network(
              doc.url,
              width: double.infinity,
              height: 245,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  height: 245,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 245,
                color: AppColors.surfaceAlt,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 42, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'تصویر قابل نمایش نیست',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Doc> _collectDocs(Map<String, dynamic> d) {
    final v = _vehicle(d);
    final out = <_Doc>[];

    void add(String title, String url) {
      if (url.isNotEmpty) out.add(_Doc(title, url));
    }

    add('عکس پروفایل راننده', _pick(d, _photoKeys));
    add(
      'روی کارت هویت',
      _pick(d, const [
        'cnicFrontImage',
        'cnicFrontImageUrl',
        'idCardFrontImage',
        'identityCardFrontImage',
        'idCardUrl',
      ]),
    );
    add(
      'پشت کارت هویت',
      _pick(d, const [
        'cnicBackImage',
        'cnicBackImageUrl',
        'idCardBackImage',
        'identityCardBackImage',
      ]),
    );
    add(
      'عکس سلفی با کارت هویت',
      _pick(d, const [
        'driverFaceWithCnic',
        'driverFaceWithCnicImage',
        'cnicWithSelfieImage',
        'selfieWithCnic',
      ]),
    );
    add(
      'روی گواهینامه',
      _pick(d, const [
        'drivingLicenseFrontImage',
        'drivingLicenseFrontImageUrl',
        'licenseFrontImage',
        'drivingLicenseUrl',
        'licenseUrl',
      ]),
    );
    add(
      'پشت گواهینامه',
      _pick(d, const [
        'drivingLicenseBackImage',
        'drivingLicenseBackImageUrl',
        'licenseBackImage',
      ]),
    );
    add('عکس وسیلهٔ نقلیه', _pick(v, _vehiclePhotoKeys));
    add(
      'روی سند وسیلهٔ نقلیه',
      _pick(v, const [
        'registrationCertificateFrontImage',
        'vehicleRegistrationFrontImage',
        'registrationFrontImage',
        'vehicleRegistrationFrontImageUrl',
      ]),
    );
    add(
      'پشت سند وسیلهٔ نقلیه',
      _pick(v, const [
        'registrationCertificateBackImage',
        'vehicleRegistrationBackImage',
        'registrationBackImage',
        'vehicleRegistrationBackImageUrl',
      ]),
    );

    final seen = <String>{};
    return out.where((e) => seen.add(e.url)).toList();
  }

  // ───────── خواندن فیلدها ─────────
  Map<String, dynamic> _vehicle(Map<String, dynamic> d) {
    final v = d['vehicleInfo'];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  String _pick(
    Map<String, dynamic> d,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final k in keys) {
      final v = d[k];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num || v is bool) return v.toString();
    }
    return fallback;
  }

  String _name(Map<String, dynamic> d, {String fallback = ''}) {
    final first = _pick(d, const ['firstName', 'firstname', 'first_name']);
    final last = _pick(d, const [
      'secondName',
      'lastName',
      'lastname',
      'last_name',
      'surname',
    ]);
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;

    return _pick(
      d,
      const [
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

  String _plate(Map<String, dynamic> v) {
    final province = _pick(v, const ['plateProvince', 'province']);
    final category = _pick(v, const ['plateCategory', 'category']);
    final number = _pick(v, const [
      'registrationPlateNumber',
      'plateNumber',
      'carNumber',
      'plate',
    ]);

    final parts = [
      if (province.isNotEmpty) province,
      if (category.isNotEmpty) category,
      if (number.isNotEmpty) number,
    ];
    if (parts.isEmpty) return '';

    final plateType = _pick(v, const ['plateType', 'type']);
    final result = parts.join(' - ');
    if (plateType.isNotEmpty &&
        plateType.toLowerCase() != _pick(v, const ['type']).toLowerCase()) {
      return '$result ($plateType)';
    }
    return result;
  }

  String _typeLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return 'وسیلهٔ نقلیه';
    if (const ['bike', 'motorbike', 'motorcycle', 'موترسایکل', 'موتورسیکلت']
        .contains(v)) {
      return 'موترسایکل';
    }
    if (const ['cargo', 'truck', 'freight', 'باربری'].contains(v)) {
      return 'باربری';
    }
    if (const ['car', 'taxi', 'auto', 'موتر', 'تاکسی'].contains(v)) {
      return 'تاکسی';
    }
    return raw.trim();
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'موترسایکل':
        return Icons.two_wheeler_rounded;
      case 'باربری':
        return Icons.local_shipping_rounded;
      default:
        return Icons.local_taxi_rounded;
    }
  }

  // ───────── وضعیت ─────────
  _Status _status(Map<String, dynamic> d) {
    if (_isBlocked(d)) return _Status.blocked;
    if (_isApproved(d)) return _Status.approved;
    return _Status.pending;
  }

  bool _isApproved(Map<String, dynamic> d) {
    final v = d['isApproved'];
    if (v == true) return true;
    final t = v?.toString().trim().toLowerCase();
    if (t == 'true' || t == 'approved' || t == 'yes') return true;
    return d['status']?.toString().trim().toLowerCase() == 'approved';
  }

  bool _isBlocked(Map<String, dynamic> d) {
    if (d['isBlocked'] == true) return true;
    final b = d['blockStatus']?.toString().trim().toLowerCase();
    final s = d['status']?.toString().trim().toLowerCase();
    return b == 'yes' || b == 'blocked' || s == 'blocked';
  }

  Color _statusColor(_Status s) {
    switch (s) {
      case _Status.approved:
        return AppColors.ok;
      case _Status.blocked:
        return AppColors.danger;
      case _Status.pending:
        return AppColors.warning;
    }
  }

  String _statusLabel(_Status s) {
    switch (s) {
      case _Status.approved:
        return 'تأیید شده';
      case _Status.blocked:
        return 'مسدود شده';
      case _Status.pending:
        return 'در انتظار';
    }
  }

  IconData _statusIcon(_Status s) {
    switch (s) {
      case _Status.approved:
        return Icons.verified_rounded;
      case _Status.blocked:
        return Icons.block_rounded;
      case _Status.pending:
        return Icons.pending_actions_rounded;
    }
  }
}
