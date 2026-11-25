import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/dashboard/side_navigation_drawer.dart';
import 'package:safir_admin/firebase_options.dart';
import 'package:safir_admin/pages/login_page.dart';
import 'package:safir_admin/provider/driver_provider.dart';
import 'package:safir_admin/provider/user_provider.dart';
import 'package:safir_admin/theme/admin_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fa'),
        Locale('ps'),
        Locale('en'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fa'),
      startLocale: const Locale('fa'),
      child: const SafirAdminApp(),
    ),
  );
}

class SafirAdminApp extends StatefulWidget {
  const SafirAdminApp({super.key});

  @override
  State<SafirAdminApp> createState() => _SafirAdminAppState();
}

class _SafirAdminAppState extends State<SafirAdminApp>
    with WidgetsBindingObserver {
  final _theme = AdminThemeController.instance;
  bool _appliedDark = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _theme.addListener(_onThemeChanged);
    _theme.applyToColors();
    _appliedDark = AppColors.isDark;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _theme.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _onThemeChanged();

  void _onThemeChanged() {
    final dark = _theme.resolveDark();
    if (dark == _appliedDark) return;

    // رنگ‌ها از AppColors خوانده می‌شوند؛ پس کل درخت باید دوباره ساخته شود.
    _appliedDark = dark;
    AppColors.isDark = dark;
    setState(() {});
    _markAllDirty();
  }

  void _markAllDirty() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  ThemeData _buildTheme() {
    final dark = AppColors.isDark;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IranYekan',
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.surface,
      dividerColor: AppColors.border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.brand,
        surface: AppColors.surface,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontFamily: 'IranYekan',
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.brand, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentButton,
          foregroundColor: AppColors.buttonText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(
            fontFamily: 'IranYekan',
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontFamily: 'IranYekan',
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'IranYekan',
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'IranYekan',
          color: AppColors.textSecondary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'IranYekan',
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriverProvider>(
          create: (_) => DriverProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safir Admin Panel',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) {
          final code = context.locale.languageCode;
          final direction = code == 'fa' || code == 'ps'
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr;

          return Directionality(
            textDirection: direction,
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: _buildTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return _AuthStatePage(
            icon: Icons.error_outline_rounded,
            title: 'خطا در بررسی وضعیت ورود',
            message: authSnapshot.error.toString(),
            color: AppColors.danger,
            showSignOutButton: true,
          );
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPage();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingPage();
            }

            if (userSnapshot.hasError) {
              return _AccessDeniedPage(
                message:
                    'خطا در دریافت اطلاعات دسترسی: ${userSnapshot.error}',
              );
            }

            final document = userSnapshot.data;

            if (document == null || !document.exists) {
              return const _AccessDeniedPage(
                message: 'برای این حساب، پروفایل مدیریتی پیدا نشد.',
              );
            }

            final userData = document.data();

            if (userData == null) {
              return const _AccessDeniedPage(
                message: 'اطلاعات پروفایل این حساب خالی است.',
              );
            }

            final isActive = userData['active'] == true;
            final role = userData['role']?.toString().trim() ?? '';
            final rawAllowedSections = userData['allowedSections'];

            final List<String> allowedSections;

            if (rawAllowedSections is List) {
              allowedSections = rawAllowedSections
                  .map((item) => item.toString().trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
            } else if (rawAllowedSections is String &&
                rawAllowedSections.trim().isNotEmpty) {
              allowedSections = [rawAllowedSections.trim()];
            } else {
              allowedSections = <String>[];
            }

            final rawPermissions = userData['permissions'];

            final permissions = rawPermissions is Map
                ? Map<String, dynamic>.from(rawPermissions)
                : <String, dynamic>{};

            if (!isActive) {
              return const _AccessDeniedPage(
                message: 'این حساب غیرفعال است.',
              );
            }

            if (role.isEmpty) {
              return const _AccessDeniedPage(
                message: 'نقش این حساب در Firestore تعیین نشده است.',
              );
            }

            if (role == 'superAdmin') {
              return SideNavigationDrawer(
                currentLocale: context.locale,
                role: role,
                allowedSections: const ['all'],
                permissions: permissions,
              );
            }

            if (allowedSections.isEmpty) {
              return const _AccessDeniedPage(
                message: 'برای این حساب هیچ بخشی تعیین نشده است.',
              );
            }

            return SideNavigationDrawer(
              currentLocale: context.locale,
              role: role,
              allowedSections: allowedSections,
              permissions: permissions,
            );
          },
        );
      },
    );
  }
}

class RoleBasedSectionPage extends StatelessWidget {
  final String role;
  final List<String> allowedSections;
  final Locale currentLocale;

  const RoleBasedSectionPage({
    super.key,
    required this.role,
    required this.allowedSections,
    required this.currentLocale,
  });

  @override
  Widget build(BuildContext context) {
    final selectedSection = allowedSections.first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_sectionTitle(selectedSection)),
        actions: [
          const AdminThemeToggleButton(),
          IconButton(
            tooltip: 'خروج',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _SectionContent(
        section: selectedSection,
        role: role,
      ),
    );
  }

  String _sectionTitle(String section) {
    switch (section) {
      case 'dashboard':
        return 'داشبورد';
      case 'support':
        return 'پشتیبانی';
      case 'drivers':
        return 'رانندگان';
      case 'users':
        return 'کاربران';
      case 'trips':
        return 'سفرها';
      case 'staff':
        return 'مدیریت کارمندان';
      case 'commission':
        return 'کمیسیون';
      case 'fare':
        return 'تنظیمات کرایه';
      case 'settings':
        return 'تنظیمات';
      default:
        return section;
    }
  }
}

class _SectionContent extends StatelessWidget {
  final String section;
  final String role;

  const _SectionContent({
    required this.section,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(section), size: 60, color: AppColors.brand),
            const SizedBox(height: 18),
            Text(
              _title(section),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'این بخش برای نقش "$role" باز شده است.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(String section) {
    switch (section) {
      case 'dashboard':
        return 'داشبورد';
      case 'support':
        return 'صفحه پشتیبانی';
      case 'drivers':
        return 'صفحه رانندگان';
      case 'users':
        return 'صفحه کاربران';
      case 'trips':
        return 'صفحه سفرها';
      case 'staff':
        return 'مدیریت کارمندان';
      case 'commission':
        return 'صفحه کمیسیون';
      case 'fare':
        return 'تنظیمات کرایه';
      case 'settings':
        return 'صفحه تنظیمات';
      default:
        return 'بخش $section';
    }
  }

  IconData _icon(String section) {
    switch (section) {
      case 'dashboard':
        return Icons.dashboard_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      case 'drivers':
        return Icons.drive_eta_rounded;
      case 'users':
        return Icons.people_alt_rounded;
      case 'trips':
        return Icons.local_taxi_rounded;
      case 'staff':
        return Icons.manage_accounts_rounded;
      case 'commission':
        return Icons.account_balance_wallet_rounded;
      case 'fare':
        return Icons.price_change_rounded;
      case 'settings':
        return Icons.settings_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const _StateCard({required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuthStatePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final bool showSignOutButton;

  const _AuthStatePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.showSignOutButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 9),
          SelectableText(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (showSignOutButton) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('بازگشت به صفحه ورود'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  final String message;

  const _AccessDeniedPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 52, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(
            'دسترسی رد شد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('بازگشت به ورود'),
          ),
        ],
      ),
    );
  }
}
