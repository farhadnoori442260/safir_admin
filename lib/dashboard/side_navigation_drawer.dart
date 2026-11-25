import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_admin_scaffold/admin_scaffold.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/pages/staff_page.dart';
import 'package:safir_admin/dashboard/dashboard.dart';
import 'package:safir_admin/pages/driver_page.dart';
import 'package:safir_admin/pages/earnings_page.dart';
import 'package:safir_admin/pages/notifications_page.dart';
import 'package:safir_admin/pages/pricing_settings_page.dart';
import 'package:safir_admin/pages/trips_page.dart';
import 'package:safir_admin/pages/user_page.dart';
import 'package:safir_admin/theme/admin_theme_controller.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

class SideNavigationDrawer extends StatefulWidget {
  final Locale currentLocale;
  final String role;
  final List<String> allowedSections;
  final Map<String, dynamic> permissions;

  const SideNavigationDrawer({
    super.key,
    required this.currentLocale,
    required this.role,
    required this.allowedSections,
    this.permissions = const {},
  });

  @override
  State<SideNavigationDrawer> createState() => _SideNavigationDrawerState();
}

class _SideNavigationDrawerState extends State<SideNavigationDrawer> {
  String currentRoute = 'dashboard';
  bool _isLoggingOut = false;

  bool get isSuperAdmin => widget.role == 'superAdmin';

  bool canAccess(String section) {
    if (isSuperAdmin) return true;
    return widget.allowedSections.contains(section);
  }

  Widget getActiveScreen() {
  final langKey = ValueKey(
    context.locale.languageCode,
  );

  switch (currentRoute) {
    case 'dashboard':
      return Dashboard(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );

    case DriverPage.id:
  return DriverPage(
    key: langKey,
    role: widget.role,
    permissions: widget.permissions,
  );

    case UserPage.id:
      return UserPage(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );

    case TripsPage.id:
      return TripsPage(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );

    case NotificationsPage.id:
      return NotificationsPage(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );

    case 'earnings':
      return EarningsPage(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );

    case 'pricing_settings':
      return PricingSettingsPage(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );

    case StaffPage.id:
      return StaffPage(
        key: langKey,
        role: widget.role,
      );

    default:
      return Dashboard(
        key: langKey,
        role: widget.role,
        permissions: widget.permissions,
      );
  }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      showAdminSnack(
        context,
        'خطا در خروج از حساب: ${e.message ?? e.code}',
        tone: AdminTone.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      showAdminSnack(context, 'خطا در خروج از حساب: $e', tone: AdminTone.error);
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    if (_isLoggingOut) return;

    final ok = await showAdminConfirm(
      context: context,
      title: 'خروج از حساب مدیریت',
      message: 'آیا مطمئن هستید که می‌خواهید از پنل مدیریت خارج شوید؟',
      confirmText: 'خروج',
      color: AppColors.danger,
    );

    if (ok == true && mounted) await _logout();
  }

  void _showLanguageDialog(BuildContext context) {
    String selected = context.locale.languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget option(String title, String value) {
              return RadioListTile<String>(
                title: Text(
                  title,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: value,
                groupValue: selected,
                activeColor: AppColors.brand,
                onChanged: (v) {
                  if (v == null) return;
                  setDialogState(() => selected = v);
                },
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.language, color: AppColors.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'انتخاب زبان / Language',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  option('دری (Farsi)', 'fa'),
                  option('پښتو (Pashto)', 'ps'),
                  option('English', 'en'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'انصراف',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    if (selected != context.locale.languageCode) {
                      await context.setLocale(Locale(selected));
                      if (mounted) setState(() {});
                    }
                  },
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<AdminMenuItem> _buildMenuItems() {
    final items = <AdminMenuItem>[];

    void add(String section, String title, String route, IconData icon) {
      if (canAccess(section)) {
        items.add(AdminMenuItem(title: title, route: route, icon: icon));
      }
    }

    add('dashboard', 'داشبورد', 'dashboard', Icons.dashboard_rounded);
    add('drivers', 'رانندگان', DriverPage.id, Icons.drive_eta_rounded);
    add('users', 'مسافران', UserPage.id, Icons.people_alt_rounded);
    add('trips', 'سفرها', TripsPage.id, Icons.route_rounded);
    add('support', 'پشتیبانی', NotificationsPage.id,
        Icons.support_agent_rounded);
    add('commission', 'کمیسیون', 'earnings',
        Icons.account_balance_wallet_rounded);
    add('fare', 'تنظیمات کرایه', 'pricing_settings', Icons.tune_rounded);

    if (isSuperAdmin) {
      items.add(
        AdminMenuItem(
          title: 'مدیریت کارمندان',
          route: StaffPage.id,
          icon: Icons.manage_accounts_rounded,
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final dark = AppColors.isDark;
    final menuItems = _buildMenuItems();

    if (menuItems.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Safir Taxi'),
          actions: [
            IconButton(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: Center(
          child: Text(
            'برای این حساب هیچ بخشی تعیین نشده است.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final routes =
        menuItems.map((item) => item.route).whereType<String>().toList();

    if (!routes.contains(currentRoute)) {
      currentRoute = routes.first;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AdminScaffold(
        key: ValueKey('admin_scaffold_${langCode}_$dark'),
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: AppColors.border)),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Safir Taxi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          actions: [
            const AdminThemeToggleButton(),
            IconButton(
              icon: Icon(Icons.language, color: AppColors.textSecondary),
              tooltip: 'تغییر زبان',
              onPressed: () => _showLanguageDialog(context),
            ),
            IconButton(
              icon: _isLoggingOut
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.logout_rounded, color: AppColors.textSecondary),
              tooltip: 'خروج از حساب',
              onPressed:
                  _isLoggingOut ? null : () => _showLogoutDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        sideBar: SideBar(
          key: ValueKey('sidebar_${langCode}_$dark'),
          backgroundColor: AppColors.surface,
          textStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          activeBackgroundColor: AppColors.brandSoft,
          activeTextStyle: TextStyle(
            color: AppColors.brand,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          borderColor: AppColors.border,
          iconColor: AppColors.textMuted,
          activeIconColor: AppColors.brand,
          items: menuItems,
          selectedRoute: currentRoute,
          onSelected: (item) {
            final route = item.route;
            if (route == null) return;
            setState(() => currentRoute = route);
          },
        ),
        body: getActiveScreen(),
      ),
    );
  }
}
