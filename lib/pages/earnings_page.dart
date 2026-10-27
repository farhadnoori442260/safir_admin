import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

// ════════════════════════════════════════════════════════════
//  منطق: مسافر کرایه را نقد به راننده می‌دهد؛ پس «کمیسیون» بدهی راننده
//  به شرکت است. هر سفر تکمیل‌شده یک وضعیت دارد:
//     unpaid  = پرداخت‌نشده (بدهی)
//     settled = تصفیه‌شده
//  سفرهای قدیمی که این وضعیت را ندارند «ثبت‌نشده» حساب می‌شوند و با دکمهٔ
//  «ثبت کمیسیون سفرهای قدیمی» یک‌بار تکمیل می‌شوند.
//
//  ایندکس لازم (همان ایندکس صفحهٔ سفرها):
//     rides → status (Ascending) + createdAt (Descending)
// ════════════════════════════════════════════════════════════

double _commissionOf(_Doc d) =>
    AdminFormat.toNumber(d.data()['commission_amount']) ?? 0;

bool _hasCommission(_Doc d) =>
    AdminFormat.toNumber(d.data()['commission_amount']) != null;

String _statusOf(_Doc d) =>
    (d.data()['commission_status'] ?? '').toString().trim().toLowerCase();

String _driverIdOf(_Doc d) {
  final Map<String, dynamic> data = d.data();
  return (data['driver_id'] ?? data['driverId'] ?? '').toString().trim();
}

String _driverNameOf(_Doc d) {
  final Map<String, dynamic> data = d.data();
  final String name =
      (data['driver_name'] ?? data['driverName'] ?? '').toString().trim();
  return name.isEmpty ? 'نامشخص' : name;
}

String _passengerNameOf(_Doc d) {
  final Map<String, dynamic> data = d.data();
  final String name = (data['passenger_name'] ??
          data['passengerName'] ??
          data['userName'] ??
          '')
      .toString()
      .trim();
  return name.isEmpty ? 'نامشخص' : name;
}

double _fareOf(_Doc d) {
  final Map<String, dynamic> data = d.data();
  return AdminFormat.toNumber(
        data['total_fare'] ??
            data['fareAmount'] ??
            data['fare_amount'] ??
            data['fare'] ??
            data['price'] ??
            data['amount'],
      ) ??
      0;
}

DateTime? _dateOf(_Doc d) {
  final Map<String, dynamic> data = d.data();
  return AdminFormat.readDate(data['completed_at'] ?? data['completedAt']) ??
      AdminFormat.readDate(data['createdAt'] ?? data['created_at']);
}

String _shortId(String id) => id.length > 6 ? id.substring(0, 6) : id;

class _DriverDebt {
  final String driverId;
  final String name;
  double total = 0;
  final List<_Doc> docs = <_Doc>[];

  _DriverDebt(this.driverId, this.name);
}

class _MigrationChoice {
  final String status;
  final double percent;

  const _MigrationChoice(this.status, this.percent);
}

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // بدهی‌ها (همهٔ زمان‌ها)
  List<_Doc> _unpaid = <_Doc>[];
  bool _loadingUnpaid = false;
  String? _unpaidError;

  // سفرهای یک بازه
  List<_Doc> _periodDocs = <_Doc>[];
  bool _loadingPeriod = false;
  String? _periodError;
  String _period = 'month';
  String _statusFilter = 'all';
  String _search = '';
  int _visibleCount = 40;
  final TextEditingController _searchController = TextEditingController();

  // سوابق تصفیه
  List<_Doc> _settlements = <_Doc>[];
  bool _loadingSettlements = false;
  String? _settlementsError;

  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  بارگذاری داده‌ها
  // ════════════════════════════════════════════════════════════

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[
      _loadUnpaid(),
      _loadPeriod(),
      _loadSettlements(),
    ]);
  }

  Future<void> _loadUnpaid() async {
    setState(() {
      _loadingUnpaid = true;
      _unpaidError = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('rides')
              .where('commission_status', isEqualTo: 'unpaid')
              .limit(3000)
              .get();

      _unpaid = snapshot.docs;
    } catch (e) {
      _unpaidError = e.toString();
    }

    if (!mounted) return;
    setState(() => _loadingUnpaid = false);
  }

  DateTime? _periodStart() {
    final DateTime now = DateTime.now();

    switch (_period) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  Future<void> _loadPeriod() async {
    setState(() {
      _loadingPeriod = true;
      _periodError = null;
      _visibleCount = 40;
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('rides')
          .where('status', whereIn: <String>['completed', 'ended']);

      final DateTime? from = _periodStart();

      if (from != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await query.orderBy('createdAt', descending: true).limit(1000).get();

      _periodDocs = snapshot.docs;
    } catch (e) {
      _periodError = e.toString();
    }

    if (!mounted) return;
    setState(() => _loadingPeriod = false);
  }

  Future<void> _loadSettlements() async {
    setState(() {
      _loadingSettlements = true;
      _settlementsError = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('commission_settlements')
              .orderBy('settled_at', descending: true)
              .limit(100)
              .get();

      _settlements = snapshot.docs;
    } catch (e) {
      _settlementsError = e.toString();
    }

    if (!mounted) return;
    setState(() => _loadingSettlements = false);
  }

  // ════════════════════════════════════════════════════════════
  //  جمع‌ها
  // ════════════════════════════════════════════════════════════

  double get _unpaidTotal =>
      _unpaid.fold<double>(0, (double s, _Doc d) => s + _commissionOf(d));

  double get _periodTotal => _periodDocs
      .where(_hasCommission)
      .fold<double>(0, (double s, _Doc d) => s + _commissionOf(d));

  double get _periodSettled => _periodDocs
      .where((_Doc d) => _statusOf(d) == 'settled')
      .fold<double>(0, (double s, _Doc d) => s + _commissionOf(d));

  int get _legacyCount =>
      _periodDocs.where((_Doc d) => _statusOf(d).isEmpty).length;

  List<_DriverDebt> _groupDebts() {
    final Map<String, _DriverDebt> map = <String, _DriverDebt>{};

    for (final _Doc doc in _unpaid) {
      final String id = _driverIdOf(doc);
      final String key = id.isEmpty ? 'unknown' : id;

      final _DriverDebt debt =
          map.putIfAbsent(key, () => _DriverDebt(key, _driverNameOf(doc)));

      debt.total += _commissionOf(doc);
      debt.docs.add(doc);
    }

    final List<_DriverDebt> list = map.values.toList()
      ..sort((_DriverDebt a, _DriverDebt b) => b.total.compareTo(a.total));

    return list;
  }

  List<_Doc> get _filteredPeriod {
    final String q = _search.trim().toLowerCase();

    return _periodDocs.where((_Doc d) {
      final String status = _statusOf(d);

      bool statusOk;
      if (_statusFilter == 'unpaid') {
        statusOk = status == 'unpaid';
      } else if (_statusFilter == 'settled') {
        statusOk = status == 'settled';
      } else if (_statusFilter == 'legacy') {
        statusOk = status.isEmpty;
      } else {
        statusOk = true;
      }

      if (!statusOk) return false;
      if (q.isEmpty) return true;

      return _driverNameOf(d).toLowerCase().contains(q) ||
          _passengerNameOf(d).toLowerCase().contains(q) ||
          d.id.toLowerCase().contains(q);
    }).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  عملیات: تصفیه، بازگردانی، ثبت سفرهای قدیمی
  // ════════════════════════════════════════════════════════════

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    Color color = AppColors.primary,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(title),
          content: Text(message, style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _snack(String message, {Color color = Colors.green}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  /// تصفیهٔ یک یا چند سفر یک راننده
  Future<void> _settle(
    List<_Doc> docs, {
    required String driverId,
    required String driverName,
  }) async {
    if (docs.isEmpty || _isWorking) return;

    final double amount =
        docs.fold<double>(0, (double s, _Doc d) => s + _commissionOf(d));

    final bool ok = await _confirm(
      title: 'تصفیهٔ کمیسیون',
      message:
          'کمیسیون ${AdminFormat.toFa(docs.length)} سفر راننده «$driverName» '
          'به مبلغ ${AdminFormat.money(amount)} افغانی تصفیه‌شده ثبت می‌شود.\n'
          'مطمئن هستید که این مبلغ را از راننده دریافت کرده‌اید؟',
      confirmText: 'تصفیه شد',
    );

    if (!ok || !mounted) return;

    setState(() => _isWorking = true);

    try {
      final User? admin = FirebaseAuth.instance.currentUser;

      for (int start = 0; start < docs.length; start += 400) {
        final int end = start + 400 > docs.length ? docs.length : start + 400;
        final WriteBatch batch = FirebaseFirestore.instance.batch();

        for (final _Doc doc in docs.sublist(start, end)) {
          batch.update(doc.reference, <String, dynamic>{
            'commission_status': 'settled',
            'commission_settled_at': FieldValue.serverTimestamp(),
            'commission_settled_by': admin?.uid ?? '',
            'commission_settled_by_email': admin?.email ?? '',
          });
        }

        await batch.commit();
      }

      await FirebaseFirestore.instance
          .collection('commission_settlements')
          .add(<String, dynamic>{
        'driver_id': driverId,
        'driver_name': driverName,
        'amount': amount,
        'trip_count': docs.length,
        'trip_ids': docs.take(500).map((_Doc d) => d.id).toList(),
        'settled_at': FieldValue.serverTimestamp(),
        'settled_by': admin?.uid ?? '',
        'settled_by_email': admin?.email ?? '',
      });

      _snack('کمیسیون تصفیه شد');
      await _refreshAll();
    } catch (e) {
      _snack('تصفیه انجام نشد: $e', color: Colors.red);
    }

    if (mounted) setState(() => _isWorking = false);
  }

  /// برگرداندن یک سفر از «تصفیه‌شده» به «پرداخت‌نشده» (اگر اشتباه ثبت شده)
  Future<void> _revert(_Doc doc) async {
    if (_isWorking) return;

    final bool ok = await _confirm(
      title: 'بازگردانی تصفیه',
      message:
          'سفر ${_shortId(doc.id)} دوباره «پرداخت‌نشده» می‌شود و در بدهی راننده حساب می‌شود.',
      confirmText: 'بازگردانی',
      color: Colors.orange.shade800,
    );

    if (!ok || !mounted) return;

    setState(() => _isWorking = true);

    try {
      await doc.reference.update(<String, dynamic>{
        'commission_status': 'unpaid',
        'commission_settled_at': FieldValue.delete(),
        'commission_settled_by': FieldValue.delete(),
        'commission_settled_by_email': FieldValue.delete(),
        'commission_reverted_at': FieldValue.serverTimestamp(),
      });

      _snack('سفر دوباره پرداخت‌نشده شد');
      await _refreshAll();
    } catch (e) {
      _snack('بازگردانی انجام نشد: $e', color: Colors.red);
    }

    if (mounted) setState(() => _isWorking = false);
  }

  Future<_MigrationChoice?> _askMigrationChoice(double defaultPercent) async {
    String status = 'unpaid';

    final TextEditingController percentController = TextEditingController(
      text: defaultPercent == defaultPercent.truncateToDouble()
          ? defaultPercent.toStringAsFixed(0)
          : defaultPercent.toString(),
    );

    final _MigrationChoice? result = await showDialog<_MigrationChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('ثبت کمیسیون سفرهای قدیمی'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'برای ${AdminFormat.toFa(_legacyCount)} سفر قدیمیِ این بازه که '
                      'کمیسیونشان ثبت نشده، کمیسیون از روی کرایه محاسبه و ذخیره می‌شود.',
                      style: const TextStyle(height: 1.6, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'وضعیت این سفرها:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'unpaid',
                      groupValue: status,
                      title: const Text('پرداخت‌نشده (بدهی راننده)'),
                      onChanged: (String? v) =>
                          setDialogState(() => status = v ?? status),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'settled',
                      groupValue: status,
                      title: const Text('تصفیه‌شده (قبلاً دریافت شده)'),
                      onChanged: (String? v) =>
                          setDialogState(() => status = v ?? status),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: percentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'درصد کمیسیون برای سفرهایی که درصد ندارند',
                        suffixText: 'درصد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('انصراف'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double? percent =
                        AdminFormat.toNumber(percentController.text);

                    if (percent == null || percent < 0 || percent > 100) return;

                    Navigator.pop(
                      dialogContext,
                      _MigrationChoice(status, percent),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ثبت'),
                ),
              ],
            );
          },
        );
      },
    );

    percentController.dispose();
    return result;
  }

  Future<void> _migrateLegacy() async {
    if (_isWorking) return;

    final List<_Doc> legacy =
        _periodDocs.where((_Doc d) => _statusOf(d).isEmpty).toList();

    if (legacy.isEmpty) return;

    // درصد فعلی پنل، به‌عنوان پیش‌فرض
    double defaultPercent = 10;

    try {
      final DocumentSnapshot<Map<String, dynamic>> config =
          await FirebaseFirestore.instance
              .collection('settings')
              .doc('app_config')
              .get();

      final double? fromConfig = AdminFormat.toNumber(
        config.data()?['commission_percent'] ??
            config.data()?['admin_commission_percent'],
      );

      if (fromConfig != null) defaultPercent = fromConfig;
    } catch (_) {}

    if (!mounted) return;

    final _MigrationChoice? choice = await _askMigrationChoice(defaultPercent);

    if (choice == null || !mounted) return;

    setState(() => _isWorking = true);

    try {
      final User? admin = FirebaseAuth.instance.currentUser;

      int updated = 0;
      int skipped = 0;

      for (int start = 0; start < legacy.length; start += 400) {
        final int end = start + 400 > legacy.length ? legacy.length : start + 400;
        final WriteBatch batch = FirebaseFirestore.instance.batch();

        for (final _Doc doc in legacy.sublist(start, end)) {
          final Map<String, dynamic> data = doc.data();
          final double fare = _fareOf(doc);

          if (fare <= 0) {
            skipped++;
            continue;
          }

          final double? existingPercent =
              AdminFormat.toNumber(data['commission_percent']);
          final double percent = existingPercent ?? choice.percent;

          final double? existingCommission =
              AdminFormat.toNumber(data['commission_amount']);
          final double commission = existingCommission ??
              double.parse((fare * percent / 100).toStringAsFixed(2));

          final double? existingEarnings =
              AdminFormat.toNumber(data['driver_earnings']);
          final double earnings = existingEarnings ??
              double.parse((fare - commission).toStringAsFixed(2));

          final Map<String, dynamic> update = <String, dynamic>{
            if (data['total_fare'] == null) 'total_fare': fare,
            if (existingPercent == null) 'commission_percent': percent,
            if (existingCommission == null) 'commission_amount': commission,
            if (existingEarnings == null) 'driver_earnings': earnings,
            if (data['payment_method'] == null) 'payment_method': 'cash',
            'commission_status': choice.status,
          };

          if (choice.status == 'settled') {
            update['commission_settled_at'] = FieldValue.serverTimestamp();
            update['commission_settled_by'] = admin?.uid ?? '';
            update['commission_settled_by_email'] = admin?.email ?? '';
            update['commission_settled_note'] = 'سفر قدیمی (ثبت یک‌باره)';
          }

          batch.update(doc.reference, update);
          updated++;
        }

        await batch.commit();
      }

      _snack(
        '${AdminFormat.toFa(updated)} سفر ثبت شد'
        '${skipped > 0 ? ' (${AdminFormat.toFa(skipped)} سفر بدون کرایه رد شد)' : ''}',
      );

      await _refreshAll();
    } catch (e) {
      _snack('ثبت انجام نشد: $e', color: Colors.red);
    }

    if (mounted) setState(() => _isWorking = false);
  }

  // ════════════════════════════════════════════════════════════
  //  رابط کاربری
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 900;

            return Column(
              children: [
                _buildHeader(),
                _buildSummary(isMobile),
                _buildTabBar(),
                if (_isWorking)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.primary,
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDebtsTab(isMobile),
                      _buildTripsTab(isMobile),
                      _buildSettlementsTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool loading = _loadingUnpaid || _loadingPeriod || _loadingSettlements;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'کمیسیون و بدهی رانندگان',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'مسافر کرایه را نقد به راننده می‌دهد؛ کمیسیون بدهی راننده به شرکت است',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'به‌روزرسانی',
            onPressed: loading || _isWorking ? null : _refreshAll,
            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isMobile) {
    final List<Widget> cards = <Widget>[
      _summaryCard(
        title: 'کل بدهی پرداخت‌نشده',
        value: '${AdminFormat.money(_unpaidTotal)} افغانی',
        subtitle: '${AdminFormat.toFa(_unpaid.length)} سفر',
        color: Colors.orange.shade800,
        icon: Icons.hourglass_bottom_rounded,
      ),
      _summaryCard(
        title: 'کمیسیون بازهٔ انتخابی',
        value: '${AdminFormat.money(_periodTotal)} افغانی',
        subtitle: '${AdminFormat.toFa(_periodDocs.length)} سفر تکمیل‌شده',
        color: AppColors.primary,
        icon: Icons.account_balance_wallet_rounded,
      ),
      _summaryCard(
        title: 'تصفیه‌شده در این بازه',
        value: '${AdminFormat.money(_periodSettled)} افغانی',
        subtitle: _legacyCount > 0
            ? '${AdminFormat.toFa(_legacyCount)} سفر بدون ثبت کمیسیون'
            : 'همهٔ سفرها ثبت شده‌اند',
        color: Colors.green,
        icon: Icons.verified_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: isMobile
          ? Column(
              children: cards
                  .map((Widget c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: c,
                      ))
                  .toList(),
            )
          : Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(13),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(height: 40, text: 'بدهی رانندگان'),
          Tab(height: 40, text: 'کمیسیون سفرها'),
          Tab(height: 40, text: 'سوابق تصفیه'),
        ],
      ),
    );
  }

  // ───────── تب ۱: بدهی رانندگان ─────────

  Widget _buildDebtsTab(bool isMobile) {
    if (_unpaidError != null && _unpaid.isEmpty) {
      return _scrollable(_stateBox(Icons.error_outline_rounded, Colors.red.shade600, _friendly(_unpaidError!), selectable: true));
    }

    if (_loadingUnpaid && _unpaid.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final List<_DriverDebt> debts = _groupDebts();

    if (debts.isEmpty) {
      return _scrollable(
        _stateBox(
          Icons.celebration_rounded,
          Colors.green,
          'بدهی پرداخت‌نشده‌ای وجود ندارد',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: debts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildDebtCard(debts[index]),
    );
  }

  Widget _buildDebtCard(_DriverDebt debt) {
    final List<_Doc> sorted = List<_Doc>.of(debt.docs)
      ..sort((_Doc a, _Doc b) {
        final DateTime? da = _dateOf(a);
        final DateTime? db = _dateOf(b);
        return (db?.millisecondsSinceEpoch ?? 0)
            .compareTo(da?.millisecondsSinceEpoch ?? 0);
      });

    return Container(
      decoration: _cardDecoration(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_taxi_rounded, color: Colors.orange.shade800, size: 20),
          ),
          title: Text(
            debt.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '${AdminFormat.toFa(debt.docs.length)} سفر پرداخت‌نشده',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${AdminFormat.money(debt.total)} افغانی',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: _isWorking
                      ? null
                      : () => _settle(
                            debt.docs,
                            driverId: debt.driverId,
                            driverName: debt.name,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text('تصفیهٔ کامل', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          children: sorted.take(100).map((_Doc doc) {
            final DateTime? date = _dateOf(doc);

            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Text(
                    _shortId(doc.id),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      date == null ? '--' : AdminFormat.jalaliDateTime(date),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5),
                    ),
                  ),
                  Text(
                    '${AdminFormat.money(_fareOf(doc))} ← ${AdminFormat.money(_commissionOf(doc))}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isWorking
                        ? null
                        : () => _settle(
                              <_Doc>[doc],
                              driverId: debt.driverId,
                              driverName: debt.name,
                            ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('تصفیه', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ───────── تب ۲: کمیسیون سفرها ─────────

  Widget _buildTripsTab(bool isMobile) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTripsControls(isMobile),
        const SizedBox(height: 12),
        _buildTripsBody(isMobile),
      ],
    );
  }

  Widget _buildTripsControls(bool isMobile) {
    final Widget search = TextField(
      controller: _searchController,
      onChanged: (String v) => setState(() {
        _search = v;
        _visibleCount = 40;
      }),
      decoration: InputDecoration(
        hintText: 'جستجو: راننده، مسافر یا کد سفر...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    Widget dropdown({
      required String value,
      required List<DropdownMenuItem<String>> items,
      required ValueChanged<String?> onChanged,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
            items: items,
            onChanged: onChanged,
          ),
        ),
      );
    }

    final Widget period = dropdown(
      value: _period,
      items: const [
        DropdownMenuItem(value: 'today', child: Text('امروز')),
        DropdownMenuItem(value: 'week', child: Text('۷ روز اخیر')),
        DropdownMenuItem(value: 'month', child: Text('۳۰ روز اخیر')),
        DropdownMenuItem(value: 'all', child: Text('همهٔ زمان‌ها')),
      ],
      onChanged: (String? v) {
        if (v == null || v == _period) return;
        setState(() => _period = v);
        _loadPeriod();
      },
    );

    final Widget status = dropdown(
      value: _statusFilter,
      items: const [
        DropdownMenuItem(value: 'all', child: Text('همهٔ وضعیت‌ها')),
        DropdownMenuItem(value: 'unpaid', child: Text('پرداخت‌نشده')),
        DropdownMenuItem(value: 'settled', child: Text('تصفیه‌شده')),
        DropdownMenuItem(value: 'legacy', child: Text('ثبت‌نشده (قدیمی)')),
      ],
      onChanged: (String? v) {
        if (v == null) return;
        setState(() {
          _statusFilter = v;
          _visibleCount = 40;
        });
      },
    );

    final Widget migrate = _legacyCount > 0
        ? SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _isWorking ? null : _migrateLegacy,
              icon: const Icon(Icons.history_edu_rounded, size: 18),
              label: Text(
                'ثبت کمیسیون سفرهای قدیمی (${AdminFormat.toFa(_legacyCount)})',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 8),
          period,
          const SizedBox(height: 8),
          status,
          if (_legacyCount > 0) ...[const SizedBox(height: 8), migrate],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 10),
            Expanded(child: period),
            const SizedBox(width: 10),
            Expanded(child: status),
          ],
        ),
        if (_legacyCount > 0) ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: migrate),
        ],
      ],
    );
  }

  Widget _buildTripsBody(bool isMobile) {
    if (_periodError != null && _periodDocs.isEmpty) {
      return _stateBox(Icons.error_outline_rounded, Colors.red.shade600, _friendly(_periodError!), selectable: true);
    }

    if (_loadingPeriod && _periodDocs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final List<_Doc> filtered = _filteredPeriod;

    if (filtered.isEmpty) {
      return _stateBox(Icons.search_off_rounded, Colors.grey.shade500, 'سفری با این مشخصات پیدا نشد');
    }

    final List<_Doc> visible = filtered.take(_visibleCount).toList();

    return Column(
      children: [
        ...visible.map(
          (_Doc doc) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTripRow(doc, isMobile),
          ),
        ),
        if (filtered.length > visible.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _visibleCount += 40),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(
                'نمایش بیشتر (${AdminFormat.toFa(filtered.length - visible.length)} سفر دیگر)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        if (_periodDocs.length >= 1000)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'فقط ۱٬۰۰۰ سفر آخر این بازه بارگذاری شده است. بازهٔ کوتاه‌تری انتخاب کنید.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 11.5),
            ),
          ),
      ],
    );
  }

  Widget _buildTripRow(_Doc doc, bool isMobile) {
    final String status = _statusOf(doc);
    final DateTime? date = _dateOf(doc);
    final bool hasCommission = _hasCommission(doc);

    Color statusColor;
    String statusText;

    if (status == 'settled') {
      statusColor = Colors.green;
      statusText = 'تصفیه‌شده';
    } else if (status == 'unpaid') {
      statusColor = Colors.orange.shade800;
      statusText = 'پرداخت‌نشده';
    } else {
      statusColor = Colors.grey;
      statusText = 'ثبت‌نشده';
    }

    final DateTime? settledAt =
        AdminFormat.readDate(doc.data()['commission_settled_at']);

    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.22)),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );

    Widget? action;

    if (status == 'unpaid') {
      action = SizedBox(
        height: 30,
        child: ElevatedButton(
          onPressed: _isWorking
              ? null
              : () => _settle(
                    <_Doc>[doc],
                    driverId: _driverIdOf(doc),
                    driverName: _driverNameOf(doc),
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: const Text('تصفیه شد', style: TextStyle(fontSize: 11)),
        ),
      );
    } else if (status == 'settled') {
      action = Tooltip(
        message: settledAt == null
            ? 'تصفیه‌شده'
            : 'تصفیه: ${AdminFormat.jalaliDateTime(settledAt)}',
        child: TextButton(
          onPressed: _isWorking ? null : () => _revert(doc),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
          ),
          child: const Text('بازگردانی', style: TextStyle(fontSize: 11)),
        ),
      );
    }

    final String fareText = '${AdminFormat.money(_fareOf(doc))} افغانی';
    final String commissionText = hasCommission
        ? '${AdminFormat.money(_commissionOf(doc))} افغانی'
        : '--';
    final String dateText = date == null ? '--' : AdminFormat.jalaliDateTime(date);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _shortId(doc.id),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateText,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5),
                  ),
                ),
                chip,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'راننده: ${_driverNameOf(doc)}  |  مسافر: ${_passengerNameOf(doc)}',
              style: const TextStyle(fontSize: 11.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'کرایه: $fareText\nکمیسیون: $commissionText',
                    style: const TextStyle(fontSize: 11.5, height: 1.6),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              _shortId(doc.id),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(dateText, style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
          ),
          Expanded(
            flex: 3,
            child: Text(_driverNameOf(doc), style: const TextStyle(fontSize: 11.5)),
          ),
          Expanded(
            flex: 3,
            child: Text(_passengerNameOf(doc), style: const TextStyle(fontSize: 11.5)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fareText,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              commissionText,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 100, child: Center(child: chip)),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: action ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── تب ۳: سوابق تصفیه ─────────

  Widget _buildSettlementsTab() {
    if (_settlementsError != null && _settlements.isEmpty) {
      return _scrollable(
        _stateBox(Icons.error_outline_rounded, Colors.red.shade600, _friendly(_settlementsError!), selectable: true),
      );
    }

    if (_loadingSettlements && _settlements.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_settlements.isEmpty) {
      return _scrollable(
        _stateBox(Icons.receipt_long_outlined, Colors.grey.shade500, 'هنوز تصفیه‌ای ثبت نشده است'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _settlements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final Map<String, dynamic> data = _settlements[index].data();
        final DateTime? date = AdminFormat.readDate(data['settled_at']);
        final double amount = AdminFormat.toNumber(data['amount']) ?? 0;
        final int count = (AdminFormat.toNumber(data['trip_count']) ?? 0).round();
        final String admin = (data['settled_by_email'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.green, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['driver_name'] ?? 'نامشخص').toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${AdminFormat.toFa(count)} سفر'
                      '${date == null ? '' : '  •  ${AdminFormat.jalaliDateTime(date)}'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                    if (admin.isNotEmpty)
                      Text(
                        'ثبت‌کننده: $admin',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                      ),
                  ],
                ),
              ),
              Text(
                '${AdminFormat.money(amount)} افغانی',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────── ابزارهای ظاهری ─────────

  Widget _scrollable(Widget child) {
    return ListView(padding: const EdgeInsets.all(16), children: [child]);
  }

  Widget _stateBox(
    IconData icon,
    Color color,
    String message, {
    bool selectable = false,
  }) {
    final TextStyle style =
        TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: 12),
          selectable
              ? SelectableText(message, textAlign: TextAlign.center, style: style)
              : Text(message, textAlign: TextAlign.center, style: style),
        ],
      ),
    );
  }

  String _friendly(String error) {
    final String lower = error.toLowerCase();

    if (lower.contains('index')) {
      return 'برای این فهرست باید یک «ایندکس» در Firestore ساخته شود.\n'
          'Firebase Console ← Firestore ← Indexes ← Add index:\n'
          'کلکسیون rides، فیلد status (Ascending) و فیلد createdAt (Descending).\n'
          'یا روی لینک داخل متن خطای زیر بزنید.\n\n$error';
    }

    if (lower.contains('permission')) {
      return 'اجازهٔ دسترسی وجود ندارد. قوانین Firestore (به‌خصوص commission_settlements) '
          'و نقش ادمین را بررسی کنید.\n\n$error';
    }

    return 'خطا در دریافت اطلاعات:\n$error';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
