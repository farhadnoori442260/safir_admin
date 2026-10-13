import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // بعد از ورود، main.dart به‌وسیله authStateChanges
      // خودش SideNavigationDrawer را نمایش می‌دهد.
      // اینجا Navigator استفاده نمی‌کنیم.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        _authErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'خطای غیرمنتظره رخ داد. دوباره تلاش کنید.',
        isError: true,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
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

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 18 : 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                ),
                child: _buildLoginCard(isMobile),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 22 : 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildBrandHeader(),
            const SizedBox(height: 30),
            _buildEmailField(),
            const SizedBox(height: 18),
            _buildPasswordField(),
            const SizedBox(height: 28),
            _buildLoginButton(),
            const SizedBox(height: 20),
            Text(
              'دسترسی این بخش فقط برای مدیر سیستم است',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
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
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 43,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ورود به پنل مدیریت سفیر',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'برای ادامه، حساب مدیریتی خود را وارد کنید',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
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
      autofillHints: const [
        AutofillHints.username,
        AutofillHints.email,
      ],
      decoration: _inputDecoration(
        label: 'ایمیل مدیر',
        icon: Icons.email_outlined,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';

        if (email.isEmpty) {
          return 'ایمیل را وارد کنید';
        }

        final emailRegex = RegExp(
          r'^[^@s]+@[^@s]+.[^@s]+$',
        );

        if (!emailRegex.hasMatch(email)) {
          return 'ایمیل معتبر وارد کنید';
        }

        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      enabled: !_isLoading,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [
        AutofillHints.password,
      ],
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _loginAdmin();
        }
      },
      decoration: _inputDecoration(
        label: 'رمز عبور',
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          tooltip: _obscurePassword
              ? 'نمایش رمز عبور'
              : 'پنهان‌کردن رمز عبور',
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'رمز عبور را وارد کنید';
        }

        if (value.length < 6) {
          return 'رمز عبور باید حداقل ۶ حرف باشد';
        }

        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _loginAdmin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
