import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class PricingSettingsPage extends StatefulWidget {
  const PricingSettingsPage({super.key});

  @override
  State<PricingSettingsPage> createState() => _PricingSettingsPageState();
}

class _PricingSettingsPageState extends State<PricingSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _commissionController = TextEditingController();
  final _taxiBaseFareController = TextEditingController();
  final _taxiPerKmController = TextEditingController();
  final _bikeBaseFareController = TextEditingController();
  final _bikePerKmController = TextEditingController();
  final _freightPerKmController = TextEditingController();
  final _intercityPerKmController = TextEditingController();
  final _searchRadiusController = TextEditingController();

  bool _isServiceActive = true;
  bool _isSaving = false;
  bool _loadedOnce = false;

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      FirebaseFirestore.instance.collection('settings').doc('config');

  @override
  void dispose() {
    _commissionController.dispose();
    _taxiBaseFareController.dispose();
    _taxiPerKmController.dispose();
    _bikeBaseFareController.dispose();
    _bikePerKmController.dispose();
    _freightPerKmController.dispose();
    _intercityPerKmController.dispose();
    _searchRadiusController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  void _fillControllers(Map<String, dynamic> data) {
    _commissionController.text =
        _toInt(data['commission_percent']).toString();

    _taxiBaseFareController.text =
        _toInt(data['base_fare_taxi']).toString();

    _taxiPerKmController.text =
        _toInt(data['per_km_taxi']).toString();

    _bikeBaseFareController.text =
        _toInt(data['base_fare_bike']).toString();

    _bikePerKmController.text =
        _toInt(data['per_km_bike']).toString();

    _freightPerKmController.text =
        _toInt(data['per_km_freight']).toString();

    _intercityPerKmController.text =
        _toInt(data['per_km_intercity']).toString();

    _searchRadiusController.text =
        _toInt(data['search_radius_km']).toString();

    _isServiceActive = data['is_service_active'] != false;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _settingsRef.set(
        {
          'commission_percent':
              int.parse(_commissionController.text.trim()),
          'base_fare_taxi':
              int.parse(_taxiBaseFareController.text.trim()),
          'per_km_taxi':
              int.parse(_taxiPerKmController.text.trim()),
          'base_fare_bike':
              int.parse(_bikeBaseFareController.text.trim()),
          'per_km_bike':
              int.parse(_bikePerKmController.text.trim()),
          'per_km_freight':
              int.parse(_freightPerKmController.text.trim()),
          'per_km_intercity':
              int.parse(_intercityPerKmController.text.trim()),
          'search_radius_km':
              int.parse(_searchRadiusController.text.trim()),
          'is_service_active': _isServiceActive,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تنظیمات با موفقیت ذخیره شد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ذخیره تنظیمات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateNumber(String? value) {
    final number = int.tryParse(value?.trim() ?? '');

    if (number == null || number < 0) {
      return 'یک عدد صفر یا بزرگ‌تر وارد کن';
    }

    return null;
  }

  Widget _buildNumberField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String suffix = 'افغانی',
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      validator: _validateNumber,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _settingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('خطا در دریافت تنظیمات: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final data = snapshot.data?.data() ?? {};

          if (!_loadedOnce) {
            _loadedOnce = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _fillControllers(data);
                });
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تنظیمات کرایه و کمیسیون',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قیمت‌ها و درصد کمیسیون اپ سفیر را از اینجا تغییر بده',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'کمیسیون و وضعیت سرویس',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildNumberField(
                          label: 'درصد کمیسیون سفیر',
                          hint: 'مثلاً 10',
                          controller: _commissionController,
                          suffix: 'درصد',
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('فعال بودن سرویس'),
                          subtitle: const Text(
                            'در صورت خاموش‌کردن، درخواست سفر جدید غیرفعال می‌شود',
                          ),
                          value: _isServiceActive,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _isServiceActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'کرایه تاکسی شهری',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildNumberField(
                          label: 'کرایه پایه تاکسی',
                          hint: 'مثلاً 50',
                          controller: _taxiBaseFareController,
                        ),
                        const SizedBox(height: 14),
                        _buildNumberField(
                          label: 'کرایه هر کیلومتر تاکسی',
                          hint: 'مثلاً 10',
                          controller: _taxiPerKmController,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'کرایه موتورسایکل',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildNumberField(
                          label: 'کرایه پایه موتورسایکل',
                          hint: 'مثلاً 30',
                          controller: _bikeBaseFareController,
                        ),
                        const SizedBox(height: 14),
                        _buildNumberField(
                          label: 'کرایه هر کیلومتر موتورسایکل',
                          hint: 'مثلاً 7',
                          controller: _bikePerKmController,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'کرایه باربری و بین‌شهری',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildNumberField(
                          label: 'کرایه هر کیلومتر باربری',
                          hint: 'مثلاً 15',
                          controller: _freightPerKmController,
                        ),
                        const SizedBox(height: 14),
                        _buildNumberField(
                          label: 'کرایه هر کیلومتر بین‌شهری',
                          hint: 'مثلاً 12',
                          controller: _intercityPerKmController,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'جستجوی راننده',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildNumberField(
                          label: 'شعاع جستجوی راننده',
                          hint: 'مثلاً 5',
                          controller: _searchRadiusController,
                          suffix: 'کیلومتر',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving
                            ? 'در حال ذخیره...'
                            : 'ذخیره تنظیمات',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
