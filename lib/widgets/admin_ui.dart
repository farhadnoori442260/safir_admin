import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

/// تبدیل ارقام لاتین به فارسی (برای نمایش یکدست).
String faDigits(String input) {
  const en = '0123456789';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(en[i], fa[i]);
  }
  return out;
}

/// ثبت فعالیت ادمین در کالکشن admin_logs (خطا نادیده گرفته می‌شود).
class AdminLog {
  AdminLog._();

  static Future<void> write({
    required String action,
    required String targetType,
    required String targetId,
    String? details,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        if (details != null) 'details': details,
        'adminUid': user?.uid,
        'adminEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

/// کارت استاندارد: سطح خنثی + خط نازک، بدون سایه و گرادیان.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? minHeight;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// پیام حالت خالی / خطا / نبود دسترسی.
class AdminStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const AdminStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: color ?? AppColors.textMuted),
          const SizedBox(height: 12),
          SelectableText(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(42),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      ),
    );
  }
}

/// چیپ وضعیت (متن + آیکن، پس‌زمینهٔ کم‌رنگ).
class AdminChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const AdminChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// آواتار گرد یا گوشه‌گرد با عکس شبکه‌ای و آیکن جایگزین.
class AdminAvatar extends StatelessWidget {
  final String? url;
  final IconData icon;
  final double size;
  final bool round;

  const AdminAvatar({
    super.key,
    required this.url,
    this.icon = Icons.person_outline_rounded,
    this.size = 38,
    this.round = true,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(icon, color: AppColors.brand, size: size * 0.55);
    final has = url != null && url!.trim().isNotEmpty;
    final radius = round ? BorderRadius.circular(size) : BorderRadius.circular(9);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: has
            ? Image.network(
                url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

enum AdminTone { ok, warning, error }

void showAdminSnack(
  BuildContext context,
  String message, {
  AdminTone tone = AdminTone.ok,
}) {
  final color = tone == AdminTone.error
      ? AppColors.danger
      : tone == AdminTone.warning
          ? AppColors.warning
          : AppColors.accentButton;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: AppColors.isDark ? color.withOpacity(0.92) : color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

Future<bool?> showAdminConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  required Color color,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'انصراف',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// دکمهٔ آیکنی کوچک با پس‌زمینهٔ کم‌رنگ (برای مسدود/رفع مسدودی و ...).
class AdminIconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const AdminIconAction({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.soft(color),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
