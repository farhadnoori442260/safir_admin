import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  static const String id = 'webPageNotifications';

  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String _targetGroup = 'all';
  bool _isSending = false;

  final Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream =
      FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile),
                      const SizedBox(height: 22),
                      _buildInfoBanner(),
                      const SizedBox(height: 18),
                      _buildComposeCard(isMobile),
                      const SizedBox(height: 26),
                      _buildHistoryTitle(),
                      const SizedBox(height: 14),
                      _buildNotificationsHistory(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.20),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_active_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مدیریت اعلان‌ها',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'ارسال اطلاع‌رسانی به رانندگان و مسافران سفیر',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return content;
    }

    return Row(
      children: [
        Expanded(child: content),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_done_outlined,
                color: Colors.green.shade600,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                'ارسال از طریق سرور امن',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.blue,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'پس از ثبت اعلان، Cloud Function آن را به گروه انتخاب‌شده ارسال می‌کند. '
              'کلید FCM نباید در اپ Flutter یا پنل ادمین قرار بگیرد.',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeCard(bool isMobile) {
    final targetSelector = _buildTargetSelector();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.edit_notifications_outlined,
            title: 'ایجاد اعلان جدید',
            subtitle: 'عنوان و متن اطلاع‌رسانی را وارد کنید.',
          ),
          const SizedBox(height: 20),
          if (isMobile) ...[
            targetSelector,
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildBodyField(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTitleField()),
                const SizedBox(width: 16),
                SizedBox(
                  width: 245,
                  child: targetSelector,
                ),
              ],
            ),
          if (!isMobile) const SizedBox(height: 16),
          if (!isMobile) _buildBodyField(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _confirmSendNotification,
              icon: _isSending
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isSending ? 'در حال ثبت اعلان...' : 'ارسال اعلان',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector() {
    return DropdownButtonFormField<String>(
      value: _targetGroup,
      decoration: InputDecoration(
        labelText: 'گیرندگان پیام',
        prefixIcon: const Icon(
          Icons.groups_outlined,
          color: AppColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.3,
          ),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('همه کاربران و رانندگان'),
        ),
        DropdownMenuItem(
          value: 'drivers',
          child: Text('فقط رانندگان'),
        ),
        DropdownMenuItem(
          value: 'users',
          child: Text('فقط مسافران'),
        ),
      ],
      onChanged: _isSending
          ? null
          : (value) {
              if (value == null) return;

              setState(() {
                _targetGroup = value;
              });
            },
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      enabled: !_isSending,
      maxLength: 90,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'عنوان پیام',
        hint: 'مثال: تغییر در قوانین سفیر',
        icon: Icons.title_rounded,
      ),
    );
  }

  Widget _buildBodyField() {
    return TextField(
      controller: _bodyController,
      enabled: !_isSending,
      maxLength: 500,
      minLines: 4,
      maxLines: 6,
      textInputAction: TextInputAction.newline,
      decoration: _inputDecoration(
        label: 'متن پیام',
        hint: 'متن کامل پیام اطلاع‌رسانی را اینجا بنویسید...',
        icon: Icons.notes_rounded,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
      ),
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.3,
        ),
      ),
    );
  }

  Widget _buildHistoryTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.history_rounded,
            color: AppColors.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'تاریخچه اعلان‌ها',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsHistory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
  return _buildStateMessage(
    icon: Icons.error_outline_rounded,
    message: 'خطا در دریافت تاریخچه: ${snapshot.error}',
    color: Colors.red.shade600,
  );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(38),
            decoration: _cardDecoration(),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _buildStateMessage(
            icon: Icons.notifications_none_rounded,
            message: 'هنوز هیچ اعلانی ارسال نشده است.',
            color: Colors.grey.shade500,
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _buildNotificationItem(documents[index]);
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final title = _readText(
      data,
      ['title'],
      fallback: 'بدون عنوان',
    );

    final body = _readText(
      data,
      ['body', 'message'],
      fallback: '-',
    );

    final targetGroup = _readText(
      data,
      ['targetGroup', 'target_group'],
      fallback: 'all',
    );

    final status = _readText(
      data,
      ['status'],
      fallback: 'sent',
    );

    final createdAt = _readTimestamp(
      data,
      [
        'createdAt',
        'created_at',
      ],
    );

    final statusInfo = _notificationStatusInfo(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusInfo.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusInfo.icon,
              color: statusInfo.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTargetChip(targetGroup),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: Colors.grey.shade500,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDateTime(createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      statusInfo.icon,
                      color: statusInfo.color,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusInfo.label,
                      style: TextStyle(
                        color: statusInfo.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'عملیات اعلان',
            onSelected: (value) {
              if (value == 'disable') {
                _changeNotificationStatus(
                  document.id,
                  'disabled',
                );
              } else if (value == 'retry') {
                _changeNotificationStatus(
                  document.id,
                  'pending',
                );
              }
            },
            itemBuilder: (context) {
              return [
                if (status != 'disabled')
                  const PopupMenuItem(
                    value: 'disable',
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text('غیرفعال کردن'),
                      ],
                    ),
                  ),
                if (status == 'failed' || status == 'disabled')
                  const PopupMenuItem(
                    value: 'retry',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text('ارسال مجدد'),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String targetGroup) {
    String label;
    Color color;
    IconData icon;

    switch (targetGroup) {
      case 'drivers':
        label = 'رانندگان';
        color = Colors.orange.shade800;
        icon = Icons.local_taxi_outlined;
        break;
      case 'users':
        label = 'مسافران';
        color = Colors.blue;
        icon = Icons.person_outline_rounded;
        break;
      default:
        label = 'همه';
        color = Colors.green;
        icon = Icons.groups_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnackBar(
        'لطفاً عنوان و متن پیام را وارد کنید.',
        Colors.orange,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'تأیید ارسال اعلان',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'آیا مطمئن هستید که می‌خواهید این اعلان را برای '
            '${_targetGroupLabel(_targetGroup)} ارسال کنید؟',
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('ارسال'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _createNotification();
    }
  }

  Future<void> _createNotification() async {
    if (_isSending) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final notificationReference =
          FirebaseFirestore.instance.collection('notifications').doc();

      await notificationReference.set({
        'title': title,
        'body': body,
        'targetGroup': _targetGroup,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'sentAt': null,
        'isRead': false,
        'isActive': true,
        'sendAttempts': 0,
        'source': 'admin_panel',
      });

      await FirebaseFirestore.instance.collection('activities').add({
        'title': 'ثبت اعلان عمومی',
        'subtitle':
            'پیام برای ${_targetGroupLabel(_targetGroup)} ثبت شد: $title',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'notification',
      });

      if (!mounted) return;

      _titleController.clear();
      _bodyController.clear();

      _showSnackBar(
        'اعلان ثبت شد و برای ارسال در صف قرار گرفت.',
        Colors.green,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در ثبت اعلان: ${e.message ?? e.code}',
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در ثبت اعلان: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _changeNotificationStatus(
    String notificationId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': status,
        'isActive': status != 'disabled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar(
        status == 'disabled'
            ? 'اعلان غیرفعال شد.'
            : 'اعلان برای ارسال مجدد در صف قرار گرفت.',
        status == 'disabled' ? Colors.orange : Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در به‌روزرسانی اعلان: $e',
        Colors.red,
      );
    }
  }

  String _targetGroupLabel(String targetGroup) {
    switch (targetGroup) {
      case 'drivers':
        return 'رانندگان';
      case 'users':
        return 'مسافران';
      default:
        return 'همه کاربران و رانندگان';
    }
  }

  _NotificationStatusInfo _notificationStatusInfo(
    String rawStatus,
  ) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'pending':
        return const _NotificationStatusInfo(
          label: 'در صف ارسال',
          color: Colors.orange,
          icon: Icons.schedule_rounded,
        );
      case 'sending':
        return const _NotificationStatusInfo(
          label: 'در حال ارسال',
          color: Colors.blue,
          icon: Icons.sync_rounded,
        );
      case 'sent':
        return const _NotificationStatusInfo(
          label: 'ارسال شد',
          color: Colors.green,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'failed':
        return const _NotificationStatusInfo(
          label: 'ارسال ناموفق',
          color: Colors.red,
          icon: Icons.error_outline_rounded,
        );
      case 'disabled':
        return const _NotificationStatusInfo(
          label: 'غیرفعال',
          color: Colors.grey,
          icon: Icons.notifications_off_outlined,
        );
      default:
        return const _NotificationStatusInfo(
          label: 'نامشخص',
          color: Colors.grey,
          icon: Icons.info_outline_rounded,
        );
    }
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
    }

    return fallback;
  }

  Timestamp? _readTimestamp(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value;
      }

      if (value is DateTime) {
        return Timestamp.fromDate(value);
      }

      if (value is int) {
        return Timestamp.fromMillisecondsSinceEpoch(value);
      }

      if (value is String) {
        final parsed = DateTime.tryParse(value);

        if (parsed != null) {
          return Timestamp.fromDate(parsed);
        }
      }
    }

    return null;
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'هم‌اکنون';
    }

    final date = timestamp.toDate();

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}/$month/$day - $hour:$minute';
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

  Widget _buildCardTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
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
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(height: 13),
          Text(
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _NotificationStatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _NotificationStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
