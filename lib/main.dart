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

class SafirAdminApp extends StatelessWidget {
  const SafirAdminApp({super.key});

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
          final localeCode = context.locale.languageCode;

          final direction =
              localeCode == 'fa' || localeCode == 'ps'
                  ? ui.TextDirection.rtl
                  : ui.TextDirection.ltr;

          return Directionality(
            textDirection: direction,
            child: child ?? const SizedBox.shrink(),
          );
        },

        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'IranYekan',
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),

          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            brightness: Brightness.light,
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontFamily: 'IranYekan',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.3,
              ),
            ),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
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
            color: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontFamily: 'IranYekan',
              color: Colors.black87,
            ),
            bodySmall: TextStyle(
              fontFamily: 'IranYekan',
              color: Colors.black54,
            ),
          ),
        ),

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
            color: Colors.red,
            showSignOutButton: true,
          );
        }

        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingPage();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const _LoadingPage();
            }

            if (userSnapshot.hasError) {
              return _AccessDeniedPage(
                message:
                    'خطا در دریافت اطلاعات دسترسی: '
                    '${userSnapshot.error}',
              );
            }

            final document = userSnapshot.data;

            if (document == null || !document.exists) {
              return const _AccessDeniedPage(
                message:
                    'برای این حساب، پروفایل مدیریتی پیدا نشد.',
              );
            }

            final userData = document.data();

            if (userData == null) {
              return const _AccessDeniedPage(
                message:
                    'اطلاعات پروفایل این حساب خالی است.',
              );
            }

            final isActive = userData['active'] == true;

            final role = userData['role']?.toString().trim() ?? '';

            final rawAllowedSections =
                userData['allowedSections'];

            final allowedSections =
                rawAllowedSections is List
                    ? rawAllowedSections
                        .map((item) => item.toString().trim())
                        .where((item) => item.isNotEmpty)
                        .toList()
                    : <String>[];

            final rawPermissions =
                userData['permissions'];

            final permissions =
                rawPermissions is Map
                    ? Map<String, dynamic>.from(
                        rawPermissions,
                      )
                    : <String, dynamic>{};

            if (!isActive) {
              return const _AccessDeniedPage(
                message: 'این حساب غیرفعال است.',
              );
            }

            if (role.isEmpty) {
              return const _AccessDeniedPage(
                message:
                    'نقش این حساب در Firestore تعیین نشده است.',
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
                message:
                    'برای این حساب هیچ بخشی تعیین نشده است.',
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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          _sectionTitle(selectedSection),
        ),
        actions: [
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
      case 'support':
        return 'پشتیبانی';
      case 'drivers':
        return 'رانندگان';
      case 'users':
        return 'کاربران';
      case 'trips':
        return 'سفرها';
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
    final title = _title(section);
    final icon = _icon(section);

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'این بخش برای نقش "$role" باز شده است.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'کنترل دسترسی با موفقیت کار می‌کند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(String section) {
    switch (section) {
      case 'support':
        return 'صفحه پشتیبانی';
      case 'drivers':
        return 'صفحه رانندگان';
      case 'users':
        return 'صفحه کاربران';
      case 'trips':
        return 'صفحه سفرها';
      case 'settings':
        return 'صفحه تنظیمات';
      default:
        return 'بخش $section';
    }
  }

  IconData _icon(String section) {
    switch (section) {
      case 'support':
        return Icons.support_agent_rounded;
      case 'drivers':
        return Icons.drive_eta_rounded;
      case 'users':
        return Icons.people_alt_rounded;
      case 'trips':
        return Icons.local_taxi_rounded;
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
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FB),
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 9),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.5,
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
        ),
      ),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  final String message;

  const _AccessDeniedPage({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'دسترسی رد شد',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.5,
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
        ),
      ),
    );
  }
}
