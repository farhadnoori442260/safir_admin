import 'package:flutter/material.dart';

class StaffPage extends StatelessWidget {
  static const String id = 'staff';

  final String role;

  const StaffPage({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Text(
          role == 'superAdmin'
              ? 'مدیریت کارمندان'
              : 'دسترسی ندارید',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
