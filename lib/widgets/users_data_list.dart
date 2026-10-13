import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class UsersDataList extends StatefulWidget {
  const UsersDataList({super.key});

  @override
  State<UsersDataList> createState() => _UsersDataListState();
}

class _UsersDataListState extends State<UsersDataList> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream =
      FirebaseFirestore.instance.collection('users').snapshots();

  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
  return _buildStateMessage(
    icon: Icons.error_outline_rounded,
    message: 'خطا در خواندن کاربران: ${snapshot.error}',
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
            message: 'no_users_registered'.tr(),
            color: Colors.grey.shade500,
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: documents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _buildUserRow(
              context,
              documents[index],
            );
          },
        );
      },
    );
  }

  Widget _buildUserRow(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final userId = document.id;

    final name = _readText(
      data,
      [
        'name',
        'userName',
        'username',
        'fullName',
        'full_name',
        'displayName',
      ],
      fallback: 'unknown'.tr(),
    );

    final email = _readText(
      data,
      [
        'email',
        'emailAddress',
        'email_address',
      ],
      fallback: 'not_registered'.tr(),
    );

    final phone = _readText(
      data,
      [
        'phone',
        'phoneNumber',
        'phone_number',
        'mobile',
      ],
      fallback: 'not_registered'.tr(),
    );

    final isBlocked = _isBlocked(data);

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
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
              child: _buildUserIdentity(
                name: name,
                data: data,
              ),
            ),
            _dataCell(
              child: _buildEmail(email),
            ),
            _dataCell(
              child: _buildPhone(phone),
            ),
            _dataCell(
              child: _buildActions(
                context: context,
                userId: userId,
                isBlocked: isBlocked,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell({
    required Widget child,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: child,
      ),
    );
  }

  Widget _buildUserIdentity({
    required String name,
    required Map<String, dynamic> data,
  }) {
    final photoUrl = _readNullableText(
      data,
      [
        'photoUrl',
        'photo_url',
        'profileImage',
        'profile_image',
        'user_image',
        'imageUrl',
      ],
    );

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
              color: AppColors.primary,
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
                photoUrl,
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

  Widget _buildEmail(String email) {
    return Row(
      children: [
        Icon(
          Icons.email_outlined,
          size: 16,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            email,
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

  Widget _buildPhone(String phone) {
    return Row(
      children: [
        Icon(
          Icons.phone_outlined,
          size: 16,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            phone,
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

  Widget _buildActions({
    required BuildContext context,
    required String userId,
    required bool isBlocked,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isBlocked
                ? Colors.red.withOpacity(0.10)
                : Colors.green.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBlocked
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: isBlocked ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 5),
              Text(
                isBlocked ? 'مسدود' : 'فعال',
                style: TextStyle(
                  color: isBlocked ? Colors.red : Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Tooltip(
          message: isBlocked
              ? 'رفع مسدودی کاربر'
              : 'مسدود کردن کاربر',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isUpdating
                ? null
                : () {
                    _confirmBlockChange(
                      context: context,
                      userId: userId,
                      currentlyBlocked: isBlocked,
                    );
                  },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isBlocked
                    ? Colors.green.withOpacity(0.10)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isBlocked
                    ? Icons.lock_open_rounded
                    : Icons.block_rounded,
                color: isBlocked ? Colors.green : Colors.red,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmBlockChange({
    required BuildContext context,
    required String userId,
    required bool currentlyBlocked,
  }) async {
    final isUnblocking = currentlyBlocked;

    final confirmed = await _showConfirmDialog(
      context: context,
      title: isUnblocking
          ? 'رفع مسدودی کاربر'
          : 'مسدود کردن کاربر',
      message: isUnblocking
          ? 'آیا می‌خواهید این کاربر از حالت مسدود خارج شود؟'
          : 'آیا مطمئن هستید که می‌خواهید این کاربر را مسدود کنید؟',
      confirmText: isUnblocking ? 'رفع مسدودی' : 'مسدود کردن',
      color: isUnblocking ? Colors.green : Colors.red,
    );

    if (confirmed == true) {
      await _toggleBlockStatus(
        userId: userId,
        isCurrentlyBlocked: currentlyBlocked,
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

  Future<void> _toggleBlockStatus({
    required String userId,
    required bool isCurrentlyBlocked,
  }) async {
    if (_isUpdating) return;

    final newBlockState = !isCurrentlyBlocked;

    setState(() {
      _isUpdating = true;
    });

    try {
      final userReference = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      final currentDocument = await userReference.get();
      final currentData = currentDocument.data() ?? {};

      final previousStatus = _readText(
        currentData,
        [
          'status',
          'accountStatus',
          'account_status',
        ],
        fallback: 'active',
      );

      await userReference.update({
        'blockStatus': newBlockState ? 'yes' : 'no',
        'isBlocked': newBlockState,
        'status': newBlockState ? 'blocked' : _safeActiveStatus(previousStatus),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      final message = newBlockState
          ? (_safeTranslation(
              'user_blocked_msg',
              fallback: 'کاربر با موفقیت مسدود شد',
            ))
          : (_safeTranslation(
              'user_unblocked_msg',
              fallback: 'کاربر از حالت مسدود خارج شد',
            ));

      _showSnackBar(
        message,
        newBlockState ? Colors.red : Colors.green,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در به‌روزرسانی کاربر: ${e.message ?? e.code}',
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در به‌روزرسانی کاربر: $e',
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

  String _safeActiveStatus(String previousStatus) {
    final normalized = previousStatus.trim().toLowerCase();

    if (normalized.isEmpty || normalized == 'blocked') {
      return 'active';
    }

    return previousStatus;
  }

  bool _isBlocked(Map<String, dynamic> data) {
    final isBlockedValue = data['isBlocked'];

    if (isBlockedValue == true) {
      return true;
    }

    final blockStatus = data['blockStatus']?.toString().toLowerCase();
    final status = data['status']?.toString().toLowerCase();

    return blockStatus == 'yes' ||
        blockStatus == 'blocked' ||
        status == 'blocked';
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
          ],
        );

        if (nestedValue.isNotEmpty) {
          return nestedValue;
        }
      }
    }

    return fallback;
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

  String? _readNullableText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final value = _readText(data, keys);
    return value.isEmpty ? null : value;
  }

  String _safeTranslation(
    String key, {
    required String fallback,
  }) {
    final translated = key.tr();

    if (translated == key) {
      return fallback;
    }

    return translated;
  }

  void _showSnackBar(String message, Color color) {
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: color),
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
