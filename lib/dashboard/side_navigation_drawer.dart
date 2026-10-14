import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_admin_scaffold/admin_scaffold.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/dashboard/dashboard.dart';
import 'package:safir_admin/pages/driver_page.dart';
import 'package:safir_admin/pages/earnings_page.dart';
import 'package:safir_admin/pages/notifications_page.dart';
import 'package:safir_admin/pages/pricing_settings_page.dart';
import 'package:safir_admin/pages/trips_page.dart';
import 'package:safir_admin/pages/user_page.dart';

class SideNavigationDrawer extends StatefulWidget {
  final Locale currentLocale;

  const SideNavigationDrawer({
    super.key,
    required this.currentLocale,
  });

  @override
  State<SideNavigationDrawer> createState() => _SideNavigationDrawerState();
}

class _SideNavigationDrawerState extends State<SideNavigationDrawer> {
  String currentRoute = 'dashboard';
  bool _isLoggingOut = false;

  Widget getActiveScreen() {
    final langKey = ValueKey(context.locale.languageCode);

    switch (currentRoute) {
      case 'dashboard':
        return Dashboard(key: langKey);
      case DriverPage.id:
        return DriverPage(key: langKey);
      case UserPage.id:
        return UserPage(key: langKey);
      case TripsPage.id:
        return TripsPage(key: langKey);
      case NotificationsPage.id:
        return NotificationsPage(key: langKey);
        case 'earnings':
  return EarningsPage(key: langKey);
        case 'pricing_settings':
  return PricingSettingsPage(key: langKey);
      default:
        return Dashboard(key: langKey);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در خروج از حساب: ${e.message ?? e.code}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در خروج از حساب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    if (_isLoggingOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('خروج از حساب مدیریت'),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید از پنل مدیریت خارج شوید؟',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'انصراف',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('خروج'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      await _logout();
    }
  }

  void _showLanguageDialog(BuildContext context) {
    String selectedLang = context.locale.languageCode;

    String titleText = 'انتخاب زبان / ژبه انتخاب کړئ';
    String cancelText = 'انصراف';
    String confirmText = 'تأیید';

    if (context.locale.languageCode == 'en') {
      titleText = 'Select Language';
      cancelText = 'Cancel';
      confirmText = 'Confirm';
    } else if (context.locale.languageCode == 'ps') {
      titleText = 'ژبه انتخاب کړئ';
      cancelText = 'بیاتوان';
      confirmText = 'تائید';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.language,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(
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
                  RadioListTile<String>(
                    title: const Text('دری (Farsi)'),
                    value: 'fa',
                    groupValue: selectedLang,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedLang = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('پښتو (Pashto)'),
                    value: 'ps',
                    groupValue: selectedLang,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedLang = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('English'),
                    value: 'en',
                    groupValue: selectedLang,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedLang = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    cancelText,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    if (selectedLang != context.locale.languageCode) {
                      await context.setLocale(Locale(selectedLang));

                      if (mounted) {
                        setState(() {});
                      }
                    }
                  },
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sideBarBg = AppColors.primary;
    final activeItemBg = Colors.white.withOpacity(0.15);
    const textStyleColor = Colors.white70;
    const activeTextColor = Colors.white;
    final currentLangCode = context.locale.languageCode;

    final menuItems = <AdminMenuItem>[
      AdminMenuItem(
        title: 'home'.tr(),
        route: 'dashboard',
        icon: CupertinoIcons.rectangle_grid_2x2_fill,
      ),
      AdminMenuItem(
        title: 'manage_drivers'.tr(),
        route: DriverPage.id,
        icon: CupertinoIcons.car_detailed,
      ),
      AdminMenuItem(
        title: 'manage_users'.tr(),
        route: UserPage.id,
        icon: CupertinoIcons.person_2_fill,
      ),
      AdminMenuItem(
        title: 'active_rides'.tr(),
        route: TripsPage.id,
        icon: CupertinoIcons.location_fill,
      ),
      AdminMenuItem(
        title: 'ارسال اعلان‌ها',
        route: NotificationsPage.id,
        icon: CupertinoIcons.bell_fill,
      ),
      AdminMenuItem(
        title: 'total_earned'.tr(),
        route: 'earnings',
        icon: CupertinoIcons.money_dollar,
      ),
      AdminMenuItem(
      title: 'تنظیمات کرایه و کمیسیون',
      route: 'pricing_settings',
      icon: CupertinoIcons.slider_horizontal_3,
     ),
    ];

    return Scaffold(
      body: AdminScaffold(
        key: ValueKey('admin_scaffold_$currentLangCode'),
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Safir Taxi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.language,
                color: Colors.white,
              ),
              tooltip: 'تغییر زبان',
              onPressed: () => _showLanguageDialog(context),
            ),
            IconButton(
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                    ),
              tooltip: 'خروج از حساب',
              onPressed: _isLoggingOut
                  ? null
                  : () => _showLogoutDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        sideBar: SideBar(
          key: ValueKey('sidebar_$currentLangCode'),
          backgroundColor: sideBarBg,
          textStyle: const TextStyle(
            color: textStyleColor,
            fontSize: 13,
          ),
          activeBackgroundColor: activeItemBg,
          activeTextStyle: const TextStyle(
            color: activeTextColor,
            fontWeight: FontWeight.bold,
          ),
          borderColor: AppColors.primary.withOpacity(0.3),
          iconColor: textStyleColor,
          activeIconColor: activeTextColor,
          items: menuItems,
          selectedRoute: currentRoute,
          onSelected: (itemSelected) {
            if (itemSelected.route == null) return;

            setState(() {
              currentRoute = itemSelected.route!;
            });
          },
        ),
        body: getActiveScreen(),
      ),
    );
  }
}
