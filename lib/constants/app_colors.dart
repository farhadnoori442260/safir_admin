import 'package:flutter/material.dart';

/// رنگ‌های مرکزی پنل مدیریت سفیر.
///
/// ثابت‌های قدیمی (primary, accentButton, ...) دست‌نخورده مانده‌اند تا
/// فایل‌های فعلی خراب نشوند. رنگ‌های جدید (bg, surface, border, ...)
/// با حالت روشن/تاریک تغییر می‌کنند و const نیستند.
class AppColors {
  AppColors._();

  /// با تم تاریک true می‌شود (بعداً از ThemeController).
  static bool isDark = false;

  // ───────── برند (قدیمی؛ تغییر نکرده) ─────────
  static const Color primary = Color(0xFF145A41);
  static const Color accentButton = Color(0xFF1B7A57);
  static const Color pressedButton = Color(0xFF0F4A35);
  static const Color cardBg = Color(0xFFEAF6F1);
  static const Color success = Color(0xFF22C55E);
  static const Color buttonText = Color(0xFFFFFFFF);

  static Color _p(Color light, Color dark) => isDark ? dark : light;

  // ───────── سطوح خنثی ─────────
  static Color get bg => _p(const Color(0xFFF4F6F5), const Color(0xFF0F1412));
  static Color get surface => _p(const Color(0xFFFFFFFF), const Color(0xFF181E1B));
  static Color get surfaceAlt =>
      _p(const Color(0xFFF7F9F8), const Color(0xFF1F2623));
  static Color get border => _p(const Color(0xFFE5EAE8), const Color(0xFF2A322F));

  // ───────── متن ─────────
  static Color get textPrimary =>
      _p(const Color(0xFF17211D), const Color(0xFFE8EEEB));
  static Color get textSecondary =>
      _p(const Color(0xFF55615B), const Color(0xFFA3AEA9));
  static Color get textMuted =>
      _p(const Color(0xFF8A958F), const Color(0xFF76817C));

  // ───────── تأکید برند روی سطح (آیکن/متن) ─────────
  static Color get brand => _p(primary, const Color(0xFF4CC38A));
  static Color get brandSoft => brand.withOpacity(isDark ? 0.16 : 0.09);

  // ───────── وضعیت‌ها ─────────
  static Color get ok => _p(const Color(0xFF15803D), const Color(0xFF4ADE80));
  static Color get warning =>
      _p(const Color(0xFFB45309), const Color(0xFFFBBF24));
  static Color get danger => _p(const Color(0xFFDC2626), const Color(0xFFF87171));
  static Color get info => _p(const Color(0xFF2563EB), const Color(0xFF60A5FA));

  /// پس‌زمینهٔ کم‌رنگ برای چیپ‌ها
  static Color soft(Color c) => c.withOpacity(isDark ? 0.16 : 0.10);
}
