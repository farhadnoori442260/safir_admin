import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/theme/admin_theme_controller.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

class LoginPage extends StatefulWidget {
  static const String id = 'loginPage';

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginAdmin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // بعد از ورود، main.dart با authStateChanges صفحهٔ اصلی را نشان می‌دهد.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showAdminSnack(context, _authErrorMessage(e), tone: AdminTone.error);
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(
        context,
        'خطای غیرمنتظره رخ داد. دوباره تلاش کنید.',
        tone: AdminTone.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'کاربری با این ایمیل یافت نشد.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'ایمیل یا رمز عبور اشتباه است.';
      case 'invalid-email':
        return 'فرمت ایمیل معتبر نیست.';
      case 'user-disabled':
        return 'این حساب غیرفعال شده است.';
      case 'too-many-requests':
        return 'تلاش‌های ناموفق زیاد است. چند دقیقه بعد دوباره امتحان کنید.';
      case 'operation-not-allowed':
        return 'ورود با ایمیل و رمز عبور در Firebase فعال نیست.';
      case 'network-request-failed':
        return 'اتصال اینترنت را بررسی کنید.';
      case 'requires-recent-login':
        return 'لطفاً دوباره وارد حساب شوید.';
      default:
        return 'ورود انجام نشد. کد خطا: ${error.code}';
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.brand),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.brand, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 18 : 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildLoginCard(isMobile),
                  ),
                ),
              );
            },
          ),
          const PositionedDirectional(
            top: 12,
            end: 12,
            child: SafeArea(child: AdminThemeToggleButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 22 : 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildBrandHeader(),
            const SizedBox(height: 28),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 26),
            _buildLoginButton(),
            const SizedBox(height: 18),
            Text(
              'دسترسی این بخش فقط برای مدیران سیستم است',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'ورود به پنل مدیریت سفیر',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'برای ادامه، حساب مدیریتی خود را وارد کنید',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      enabled: !_isLoading,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: AppColors.textPrimary),
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      decoration: _inputDecoration(
        label: 'ایمیل مدیر',
        icon: Icons.email_outlined,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return 'ایمیل را وارد کنید';

        // قبلاً regex اشتباه بود (\s و \. بدون بک‌اسلش) و ایمیل درست را رد می‌کرد.
        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
        return ok ? null : 'ایمیل معتبر وارد کنید';
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      enabled: !_isLoading,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(color: AppColors.textPrimary),
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) {
        if (!_isLoading) _loginAdmin();
      },
      decoration: _inputDecoration(
        label: 'رمز عبور',
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'نمایش رمز عبور' : 'پنهان‌کردن رمز عبور',
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textMuted,
          ),
          onPressed: _isLoading
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'رمز عبور را وارد کنید';
        if (value.length < 6) return 'رمز عبور باید حداقل ۶ حرف باشد';
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _loginAdmin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentButton,
          foregroundColor: AppColors.buttonText,
          disabledBackgroundColor: AppColors.accentButton.withOpacity(0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  key: ValueKey('login'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 21),
                    SizedBox(width: 10),
                    Text(
                      'ورود به سیستم',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
