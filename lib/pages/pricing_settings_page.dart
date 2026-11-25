import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';
import 'package:safir_admin/utils/permissions.dart';
import 'package:safir_admin/widgets/admin_ui.dart';

class PricingSettingsPage extends StatefulWidget {
  final String role;
  final Map<String, dynamic> permissions;

  const PricingSettingsPage({
    super.key,
    this.role = 'superAdmin',
    this.permissions = const {},
  });

  @override
  State<PricingSettingsPage> createState() => _PricingSettingsPageState();
}

class _PricingSettingsPageState extends State<PricingSettingsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // مقدار پیش‌فرض (همان مقدارهای پیش‌فرض اپ‌ها). اگر فیلدی در Firestore
  // نباشد، به‌جای «صفر» همین مقدار نشان داده می‌شود.
  static const double _defCommission = 10;
  static const double _defTaxiBase = 100;
  static const double _defTaxiPerKm = 35;
  static const double _defBikeBase = 70;
  static const double _defBikePerKm = 25;
  static const double _defFreightPerKm = 60;
  static const double _defIntercityPerKm = 45;
  static const double _defRadius = 5;
  static const double _defVip = 1.35;
  static const double _defZaranj = 0.5;
  static const double _defSuzuki = 1.0;
  static const double _defMazda = 1.67;

  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _taxiBaseFareController = TextEditingController();
  final TextEditingController _taxiPerKmController = TextEditingController();
  final TextEditingController _bikeBaseFareController = TextEditingController();
  final TextEditingController _bikePerKmController = TextEditingController();
  final TextEditingController _freightPerKmController = TextEditingController();
  final TextEditingController _intercityPerKmController =
      TextEditingController();
  final TextEditingController _searchRadiusController = TextEditingController();
  final TextEditingController _vipController = TextEditingController();
  final TextEditingController _zaranjController = TextEditingController();
  final TextEditingController _suzukiController = TextEditingController();
  final TextEditingController _mazdaController = TextEditingController();

  bool _isServiceActive = true;
  bool _intercityPerPassenger = false;
  bool _isSaving = false;
  bool _loadedOnce = false;

  bool get _canView => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: 'fare',
        key: 'view',
      );

  bool get _canEdit => Permissions.can(
        role: widget.role,
        permissions: widget.permissions,
        section: 'fare',
        key: 'update',
      );

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      FirebaseFirestore.instance.collection('settings').doc('app_config');

  List<TextEditingController> get _allControllers => <TextEditingController>[
        _commissionController,
        _taxiBaseFareController,
        _taxiPerKmController,
        _bikeBaseFareController,
        _bikePerKmController,
        _freightPerKmController,
        _intercityPerKmController,
        _searchRadiusController,
        _vipController,
        _zaranjController,
        _suzukiController,
        _mazdaController,
      ];

  @override
  void dispose() {
    for (final TextEditingController c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  خواندن و نوشتن
  // ════════════════════════════════════════════════════════════

  String _numText(Object? raw, double fallback) {
    final double value = AdminFormat.toNumber(raw) ?? fallback;

    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  void _fillControllers(Map<String, dynamic> data) {
    _commissionController.text = _numText(
      data['commission_percent'] ?? data['admin_commission_percent'],
      _defCommission,
    );
    _taxiBaseFareController.text = _numText(data['base_fare_taxi'], _defTaxiBase);
    _taxiPerKmController.text = _numText(data['per_km_taxi'], _defTaxiPerKm);
    _bikeBaseFareController.text = _numText(data['base_fare_bike'], _defBikeBase);
    _bikePerKmController.text = _numText(data['per_km_bike'], _defBikePerKm);
    _freightPerKmController.text =
        _numText(data['per_km_freight'], _defFreightPerKm);
    _intercityPerKmController.text =
        _numText(data['per_km_intercity'], _defIntercityPerKm);
    _searchRadiusController.text = _numText(data['search_radius_km'], _defRadius);
    _vipController.text = _numText(data['vip_multiplier'], _defVip);
    _zaranjController.text =
        _numText(data['freight_multiplier_zaranj'], _defZaranj);
    _suzukiController.text =
        _numText(data['freight_multiplier_suzuki'], _defSuzuki);
    _mazdaController.text =
        _numText(data['freight_multiplier_mazda'], _defMazda);

    _isServiceActive = data['is_service_active'] != false;
    _intercityPerPassenger = data['intercity_per_passenger'] == true;
  }

  double _n(TextEditingController controller, double fallback) {
    return AdminFormat.toNumber(controller.text) ?? fallback;
  }

  /// عدد صحیح را صحیح و اعشاری را اعشاری ذخیره می‌کند
  num _storable(double value) {
    return value == value.truncateToDouble() ? value.toInt() : value;
  }

  Future<void> _saveSettings() async {
    if (!_canEdit) return;
    if (!_formKey.currentState!.validate()) return;

    final bool ok = await showAdminConfirm(
          context: context,
          title: 'ذخیرهٔ تنظیمات کرایه',
          message: 'تغییرات بلافاصله روی اپ مسافر و راننده اعمال می‌شود. '
              'مطمئن هستید؟',
          confirmText: 'ذخیره',
        ) ??
        false;

    if (!ok || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final double commission = _n(_commissionController, _defCommission);

      await _settingsRef.set(
        <String, dynamic>{
          'commission_percent': _storable(commission),
          // همان مقدار در فیلد قدیمی هم نوشته می‌شود تا دو فیلد هیچ‌وقت
          // با هم فرق نکنند
          'admin_commission_percent': _storable(commission),
          'base_fare_taxi': _storable(_n(_taxiBaseFareController, _defTaxiBase)),
          'per_km_taxi': _storable(_n(_taxiPerKmController, _defTaxiPerKm)),
          'base_fare_bike': _storable(_n(_bikeBaseFareController, _defBikeBase)),
          'per_km_bike': _storable(_n(_bikePerKmController, _defBikePerKm)),
          'per_km_freight':
              _storable(_n(_freightPerKmController, _defFreightPerKm)),
          'per_km_intercity':
              _storable(_n(_intercityPerKmController, _defIntercityPerKm)),
          'search_radius_km':
              _storable(_n(_searchRadiusController, _defRadius)),
          'vip_multiplier': _storable(_n(_vipController, _defVip)),
          'freight_multiplier_zaranj':
              _storable(_n(_zaranjController, _defZaranj)),
          'freight_multiplier_suzuki':
              _storable(_n(_suzukiController, _defSuzuki)),
          'freight_multiplier_mazda':
              _storable(_n(_mazdaController, _defMazda)),
          'intercity_per_passenger': _intercityPerPassenger,
          'is_service_active': _isServiceActive,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': FirebaseAuth.instance.currentUser?.uid ?? '',
        },
        SetOptions(merge: true),
      );

      await AdminLog.write(
        action: 'pricing_updated',
        targetType: 'settings',
        targetId: 'app_config',
        details: 'commission=${_storable(commission)}%, '
            'taxi=${_taxiBaseFareController.text}+${_taxiPerKmController.text}/km',
      );

      if (!mounted) return;

      showAdminSnack(context, 'تنظیمات با موفقیت ذخیره شد');
    } catch (e) {
      if (!mounted) return;

      showAdminSnack(
        context,
        'خطا در ذخیره تنظیمات: $e',
        tone: AdminTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اعتبارسنجی
  // ════════════════════════════════════════════════════════════

  String? Function(String?) _range(
    double min,
    double max, {
    String? message,
  }) {
    return (String? value) {
      final double? number = AdminFormat.toNumber(value ?? '');

      if (number == null || number < min || number > max) {
        return message ??
            'عددی بین ${AdminFormat.toFa(min.toString().replaceAll(RegExp(r'\.0$'), ''))} '
                'و ${AdminFormat.toFa(max.toString().replaceAll(RegExp(r'\.0$'), ''))} وارد کنید';
      }

      return null;
    };
  }

  Widget _buildNumberField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    String suffix = 'افغانی',
    bool decimal = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.surfaceAlt,
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
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  رابط کاربری
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AdminStateMessage(
              icon: Icons.lock_outline_rounded,
              message: 'شما اجازهٔ مشاهدهٔ تنظیمات کرایه را ندارید.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _settingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AdminStateMessage(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                  message: 'خطا در دریافت تنظیمات: ${snapshot.error}',
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const AdminLoading();
          }

          if (!_loadedOnce) {
            _loadedOnce = true;
            _fillControllers(snapshot.data?.data() ?? <String, dynamic>{});
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: !_canEdit,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تنظیمات کرایه و کمیسیون',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قیمت‌ها و درصد کمیسیون اپ سفیر را از اینجا تغییر بده. '
                    'بعد از ذخیره، اپ مسافر و راننده همان لحظه به‌روز می‌شوند.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (!_canEdit) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.soft(AppColors.warning),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'شما فقط اجازهٔ مشاهده دارید و نمی‌توانید تنظیمات را تغییر دهید.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),

                  _section(
                    title: 'کمیسیون و وضعیت سرویس',
                    children: [
                      _buildNumberField(
                        label: 'درصد کمیسیون سفیر',
                        hint: 'مثلاً 10',
                        controller: _commissionController,
                        suffix: 'درصد',
                        decimal: true,
                        validator: _range(0, 100),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('فعال بودن سرویس'),
                        subtitle: const Text(
                          'در صورت خاموش‌کردن، درخواست سفر جدید غیرفعال می‌شود',
                        ),
                        value: _isServiceActive,
                        activeColor: AppColors.brand,
                        onChanged: (bool value) {
                          setState(() {
                            _isServiceActive = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _section(
                    title: 'کرایه تاکسی شهری',
                    children: [
                      _buildNumberField(
                        label: 'کرایه پایه تاکسی',
                        hint: 'مثلاً 100',
                        controller: _taxiBaseFareController,
                        decimal: true,
                        validator: _range(0, 1000000),
                      ),
                      const SizedBox(height: 14),
                      _buildNumberField(
                        label: 'کرایه هر کیلومتر تاکسی',
                        hint: 'مثلاً 35',
                        controller: _taxiPerKmController,
                        decimal: true,
                        validator: _range(0, 1000000),
                      ),
                      const SizedBox(height: 14),
                      _buildNumberField(
                        label: 'ضریب قیمت تاکسی ویژه',
                        hint: 'مثلاً 1.35',
                        controller: _vipController,
                        suffix: 'برابر',
                        decimal: true,
                        validator: _range(1, 10),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _section(
                    title: 'کرایه موتورسایکل',
                    children: [
                      _buildNumberField(
                        label: 'کرایه پایه موتورسایکل',
                        hint: 'مثلاً 70',
                        controller: _bikeBaseFareController,
                        decimal: true,
                        validator: _range(0, 1000000),
                      ),
                      const SizedBox(height: 14),
                      _buildNumberField(
                        label: 'کرایه هر کیلومتر موتورسایکل',
                        hint: 'مثلاً 25',
                        controller: _bikePerKmController,
                        decimal: true,
                        validator: _range(0, 1000000),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _section(
                    title: 'کرایه باربری',
                    children: [
                      _buildNumberField(
                        label: 'کرایه هر کیلومتر باربری (مبنا: سوزوکی)',
                        hint: 'مثلاً 60',
                        controller: _freightPerKmController,
                        decimal: true,
                        validator: _range(0, 1000000),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'قیمت هر خودرو = کرایه هر کیلومتر × ضریب خودرو × کیلومتر',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      _buildNumberField(
                        label: 'ضریب زرنج',
                        hint: 'مثلاً 0.5',
                        controller: _zaranjController,
                        suffix: 'برابر',
                        decimal: true,
                        validator: _range(0.1, 10),
                      ),
                      const SizedBox(height: 14),
                      _buildNumberField(
                        label: 'ضریب سوزوکی',
                        hint: 'مثلاً 1',
                        controller: _suzukiController,
                        suffix: 'برابر',
                        decimal: true,
                        validator: _range(0.1, 10),
                      ),
                      const SizedBox(height: 14),
                      _buildNumberField(
                        label: 'ضریب مازدا',
                        hint: 'مثلاً 1.67',
                        controller: _mazdaController,
                        suffix: 'برابر',
                        decimal: true,
                        validator: _range(0.1, 10),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _section(
                    title: 'کرایه بین‌شهری',
                    children: [
                      _buildNumberField(
                        label: 'کرایه هر کیلومتر بین‌شهری',
                        hint: 'مثلاً 45',
                        controller: _intercityPerKmController,
                        decimal: true,
                        validator: _range(0, 1000000),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('کرایه به‌ازای هر مسافر'),
                        subtitle: const Text(
                          'اگر روشن باشد، کرایه در تعداد مسافر ضرب می‌شود؛ '
                          'اگر خاموش باشد، کرایه برای کل ماشین است',
                        ),
                        value: _intercityPerPassenger,
                        activeColor: AppColors.brand,
                        onChanged: (bool value) {
                          setState(() {
                            _intercityPerPassenger = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _section(
                    title: 'جستجوی راننده',
                    children: [
                      _buildNumberField(
                        label: 'شعاع جستجوی راننده',
                        hint: 'مثلاً 5',
                        controller: _searchRadiusController,
                        suffix: 'کیلومتر',
                        decimal: true,
                        validator: _range(
                          1,
                          200,
                          message: 'شعاع باید بین ۱ تا ۲۰۰ کیلومتر باشد',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildPreview(),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_isSaving || !_canEdit) ? null : _saveSettings,
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
                      label: Text(_isSaving ? 'در حال ذخیره...' : 'ذخیره تنظیمات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentButton,
                        foregroundColor: AppColors.buttonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// پیش‌نمایش قیمت یک سفر ۱۰ کیلومتری با مقدارهای واردشده (قبل از ذخیره)
  Widget _buildPreview() {
    return AnimatedBuilder(
      animation: Listenable.merge(_allControllers),
      builder: (BuildContext context, Widget? child) {
        const double km = 10;

        final double taxi = (_n(_taxiBaseFareController, _defTaxiBase) +
                _n(_taxiPerKmController, _defTaxiPerKm) * km)
            .roundToDouble();

        final double vip =
            (taxi * _n(_vipController, _defVip)).roundToDouble();

        final double bike = (_n(_bikeBaseFareController, _defBikeBase) +
                _n(_bikePerKmController, _defBikePerKm) * km)
            .roundToDouble();

        final double freightBase =
            _n(_freightPerKmController, _defFreightPerKm) * km;

        final double zaranj =
            (freightBase * _n(_zaranjController, _defZaranj)).roundToDouble();
        final double suzuki =
            (freightBase * _n(_suzukiController, _defSuzuki)).roundToDouble();
        final double mazda =
            (freightBase * _n(_mazdaController, _defMazda)).roundToDouble();

        final double intercity =
            (_n(_intercityPerKmController, _defIntercityPerKm) * km)
                .roundToDouble();

        final double commission =
            taxi * _n(_commissionController, _defCommission) / 100;

        final List<MapEntry<String, double>> rows = <MapEntry<String, double>>[
          MapEntry<String, double>('تاکسی', taxi),
          MapEntry<String, double>('تاکسی ویژه', vip),
          MapEntry<String, double>('موتورسایکل', bike),
          MapEntry<String, double>('باربری: زرنج', zaranj),
          MapEntry<String, double>('باربری: سوزوکی', suzuki),
          MapEntry<String, double>('باربری: مازدا', mazda),
          MapEntry<String, double>(
            _intercityPerPassenger ? 'بین‌شهری (هر نفر)' : 'بین‌شهری (کل ماشین)',
            intercity,
          ),
        ];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_rounded, color: AppColors.brand),
                  SizedBox(width: 8),
                  Text(
                    'پیش‌نمایش قیمت یک سفر ۱۰ کیلومتری',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...rows.map(
                (MapEntry<String, double> row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(row.key, style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        '${AdminFormat.money(row.value)} افغانی',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 22),
              Text(
                'کمیسیون یک سفر تاکسی ۱۰ کیلومتری: '
                '${AdminFormat.money(commission)} افغانی',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );
  }
}
