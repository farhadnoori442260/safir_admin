import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/permissions.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

class UsersDataList extends StatefulWidget {
  final String searchQuery;

  /// all | active | blocked
  final String filterStatus;
  final String role;
  final Map<String, dynamic> permissions;

  const UsersDataList({
    super.key,
    this.searchQuery = '',
    this.filterStatus = 'all',
    this.role = 'superAdmin',
    this.permissions = const {},
  });

  @override
  State<UsersDataList> createState() => _UsersDataListState();
}

class _UsersDataListState extends State<UsersDataList> {
  // حداکثر ۵۰۰ کاربر؛ برای دادهٔ بزرگ‌تر باید جستجوی سمت سرور اضافه شود.
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('users').limit(500).snapshots();

  bool _isUpdating = false;

  bool get _canBlock => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: 'users',
        key: 'update',
        alternatives: const ['block', 'delete', 'edit'],
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminStateMessage(
            icon: Icons.error_outline_rounded,
            message: 'خطا در خواندن کاربران:\n${snapshot.error}',
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
            message: 'هیچ کاربری ثبت نشده است',
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
    final blocked = _isBlocked(d);

    if (widget.filterStatus == 'blocked' && !blocked) return false;
    if (widget.filterStatus == 'active' && blocked) return false;

    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    return _name(d).toLowerCase().contains(q) ||
        _email(d).toLowerCase().contains(q) ||
        _phone(d).toLowerCase().contains(q) ||
        doc.id.toLowerCase().contains(q);
  }

  Widget _row(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final blocked = _isBlocked(d);
    final name = _name(d);
    final email = _email(d);
    final phone = _phone(d);
    final photo = _pick(d, const [
      'photoUrl',
      'photo_url',
      'profileImage',
      'profile_image',
      'user_image',
      'imageUrl',
    ]);

    return AdminCard(
      minHeight: 72,
      child: Row(
        children: [
          _cell(
            Row(
              children: [
                AdminAvatar(url: photo.isEmpty ? null : photo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'نامشخص' : name,
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
          _cell(_info(Icons.email_outlined, email.isEmpty ? 'ثبت نشده' : email)),
          _cell(_info(Icons.phone_outlined, phone.isEmpty ? 'ثبت نشده' : phone)),
          _cell(_actions(context, doc.id, blocked)),
        ],
      ),
    );
  }

  Widget _cell(Widget child) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: child,
        ),
      );

  Widget _info(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, String id, bool blocked) {
    final chip = AdminChip(
      label: blocked ? 'مسدود' : 'فعال',
      icon: blocked ? Icons.block_rounded : Icons.check_circle_outline_rounded,
      color: blocked ? AppColors.danger : AppColors.ok,
    );

    if (!_canBlock) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [chip]);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip,
        const SizedBox(width: 7),
        AdminIconAction(
          icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          color: blocked ? AppColors.ok : AppColors.danger,
          tooltip: blocked ? 'رفع مسدودی کاربر' : 'مسدود کردن کاربر',
          onTap: _isUpdating ? null : () => _confirmBlock(context, id, blocked),
        ),
      ],
    );
  }

  Future<void> _confirmBlock(
    BuildContext context,
    String id,
    bool blocked,
  ) async {
    final ok = await showAdminConfirm(
      context: context,
      title: blocked ? 'رفع مسدودی کاربر' : 'مسدود کردن کاربر',
      message: blocked
          ? 'آیا می‌خواهید این کاربر از حالت مسدود خارج شود؟'
          : 'آیا مطمئن هستید که می‌خواهید این کاربر را مسدود کنید؟',
      confirmText: blocked ? 'رفع مسدودی' : 'مسدود کردن',
      color: blocked ? AppColors.accentButton : AppColors.danger,
    );
    if (ok == true) await _toggle(id, blocked);
  }

  Future<void> _toggle(String id, bool wasBlocked) async {
    if (_isUpdating || !_canBlock) return;
    final nowBlocked = !wasBlocked;

    setState(() => _isUpdating = true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(id);
      final current = (await ref.get()).data() ?? {};
      final prev = _pick(
        current,
        const ['status', 'accountStatus', 'account_status'],
        fallback: 'active',
      );
      final safePrev =
          (prev.isEmpty || prev.toLowerCase() == 'blocked') ? 'active' : prev;

      await ref.update({
        'blockStatus': nowBlocked ? 'yes' : 'no',
        'isBlocked': nowBlocked,
        'status': nowBlocked ? 'blocked' : safePrev,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AdminLog.write(
        action: nowBlocked ? 'user_blocked' : 'user_unblocked',
        targetType: 'user',
        targetId: id,
      );

      if (!mounted) return;
      showAdminSnack(
        context,
        nowBlocked ? 'کاربر با موفقیت مسدود شد' : 'کاربر از حالت مسدود خارج شد',
        tone: nowBlocked ? AdminTone.warning : AdminTone.ok,
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        showAdminSnack(
          context,
          'خطا در به‌روزرسانی کاربر: ${e.message ?? e.code}',
          tone: AdminTone.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در به‌روزرسانی کاربر: $e',
            tone: AdminTone.error);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ───────── خواندن فیلدها ─────────
  String _name(Map<String, dynamic> d) => _pick(d, const [
        'name',
        'userName',
        'username',
        'fullName',
        'full_name',
        'displayName',
      ]);

  String _email(Map<String, dynamic> d) =>
      _pick(d, const ['email', 'emailAddress', 'email_address']);

  String _phone(Map<String, dynamic> d) =>
      _pick(d, const ['phone', 'phoneNumber', 'phone_number', 'mobile']);

  bool _isBlocked(Map<String, dynamic> d) {
    if (d['isBlocked'] == true) return true;
    final b = d['blockStatus']?.toString().toLowerCase();
    final s = d['status']?.toString().toLowerCase();
    return b == 'yes' || b == 'blocked' || s == 'blocked';
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
      if (v is Map) {
        for (final n in const ['name', 'title', 'value', 'text']) {
          final x = v[n];
          if (x != null && x.toString().trim().isNotEmpty) {
            return x.toString().trim();
          }
        }
      }
    }
    return fallback;
  }
}
