import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

/// کنترل تم پنل: روشن / تاریک / خودکار (طبق سیستم).
/// ذخیرهٔ ماندگار ندارد (shared_preferences لازم نیست)؛ بعداً اضافه می‌شود.
class AdminThemeController extends ChangeNotifier {
  AdminThemeController._();
  static final AdminThemeController instance = AdminThemeController._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  bool resolveDark() {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// آیکن و دکمهٔ ساده برای نوار بالا یا منو: روشن ↔ تاریک.
  void toggle() => setMode(resolveDark() ? ThemeMode.light : ThemeMode.dark);

  void applyToColors() => AppColors.isDark = resolveDark();
}

/// دکمهٔ آمادهٔ تغییر تم؛ در هر جای نوار بالا/منو بگذارید.
class AdminThemeToggleButton extends StatelessWidget {
  const AdminThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return IconButton(
      tooltip: dark ? 'حالت روشن' : 'حالت تاریک',
      onPressed: AdminThemeController.instance.toggle,
      icon: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}
