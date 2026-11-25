/// بررسی مجوزها در یک نقطه.
///
/// توجه: این فقط پنهان‌کردن دکمه در رابط کاربری است. امنیت واقعی
/// باید در Firestore Rules هم اعمال شود.
class Permissions {
  Permissions._();

  static bool isSuperAdmin(String role) =>
      role.trim().toLowerCase() == 'superadmin';

  /// [section] مثل 'drivers' و [key] مثل 'update'.
  static bool can({
    required String role,
    required Map<String, dynamic> permissions,
    required String section,
    required String key,
    List<String> alternatives = const [],
  }) {
    if (isSuperAdmin(role)) return true;

    final raw = permissions[section];
    if (raw is! Map) return false;

    if (raw[key] == true) return true;
    for (final alt in alternatives) {
      if (raw[alt] == true) return true;
    }
    return false;
  }
}
