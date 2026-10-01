import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageHelper {
  static const Locale dari = Locale('fa');
  static const Locale pashto = Locale('ps');
  static const Locale english = Locale('en');

  static Future<void> changeToDari(BuildContext context) async {
    await context.setLocale(dari);
  }

  static Future<void> changeToPashto(BuildContext context) async {
    await context.setLocale(pashto);
  }

  static Future<void> changeToEnglish(BuildContext context) async {
    await context.setLocale(english);
  }
}
