import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';
import 'package:safir_admin/utils/admin_format.dart';

// ════════════════════════════════════════════════════════════
//  گروه‌های سفر
//
//  برای هر گروه یک کوئری جدا ساخته می‌شود (نه یک‌جا و نه کل rides).
//  همهٔ کوئری‌ها به «یک» ایندکس ترکیبی نیاز دارند:
//     کلکسیون rides  →  status (صعودی) + createdAt (نزولی)
// ════════════════════════════════════════════════════════════

enum _TripGroup { active, completed, cancelled }

const Map<_TripGroup, List<String>> _groupStatuses =
    <_TripGroup, List<String>>{
  _TripGroup.active: <String>[
    'searching',
    'accepted',
    'arrived',
    'ontrip',
  ],
  _TripGroup.completed: <String>[
    'completed',
    'ended',
  ],
  _TripGroup.cancelled: <String>[
    'cancelled_by_passenger',
    'cancelled_by_driver',
    'cancelled',
  ],
};

/// سفری که بیشتر از این مدت در حالت «جستجو» مانده، منقضی حساب می‌شود
const Duration _searchExpiry = Duration(minutes: 10);

class TripsPage extends StatefulWidget {
  static const String id = 'webPageTrips';

  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _TripsTab(group: _TripGroup.active),
                  _TripsTab(group: _TripGroup.completed),
                  _TripsTab(group: _TripGroup.cancelled),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.alt_route_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'active_rides'.tr(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'سفرها بر اساس وضعیت از هم جدا شده‌اند',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                  ),
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
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(
            height: 42,
            icon: Icon(Icons.navigation_rounded, size: 18),
            iconMargin: EdgeInsets.only(bottom: 2),
            text: 'در حال انجام',
          ),
          Tab(
            height: 42,
            icon: Icon(Icons.check_circle_rounded, size: 18),
            iconMargin: EdgeInsets.only(bottom: 2),
            text: 'انجام‌شده',
          ),
          Tab(
            height: 42,
            icon: Icon(Icons.cancel_rounded, size: 18),
            iconMargin: EdgeInsets.only(bottom: 2),
            text: 'لغوشده',
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  یک تب (یک گروه از سفرها)
// ════════════════════════════════════════════════════════════

class _TripsTab extends StatefulWidget {
  final _TripGroup group;

  const _TripsTab({required this.group});

  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _period = 'all';

  // سفرهای در حال انجام: زنده
  Stream<QuerySnapshot<Map<String, dynamic>>>? _activeStream;

  // انجام‌شده و لغوشده: صفحه‌به‌صفحه
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  bool get _isLive => widget.group == _TripGroup.active;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (_isLive) {
      _activeStream = _baseQuery().limit(100).snapshots();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPage(reset: true);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('rides')
        .where('status', whereIn: _groupStatuses[widget.group]!);

    final DateTime? from = _isLive ? null : _periodStart();

    if (from != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }

    return query.orderBy('createdAt', descending: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_isLoading) return;

    if (reset) {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
    }

    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Query<Map<String, dynamic>> query = _baseQuery().limit(_pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _docs.addAll(snapshot.docs);

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
      }

      _hasMore = snapshot.docs.length == _pageSize;
    } catch (e) {
      _error = e.toString();
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  // ════════════════════════════════════════════════════════════
  //  رابط کاربری
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildControls(isMobile),
              const SizedBox(height: 16),
              _isLive ? _buildLiveBody(isMobile) : _buildPagedBody(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(bool isMobile) {
    final Widget searchField = TextField(
      controller: _searchController,
      onChanged: (String value) {
        setState(() {
          _query = value.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'جستجو: مسافر، راننده، مبدأ، مقصد یا کد سفر...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                tooltip: 'پاک کردن',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
        ),
      ),
    );

    if (_isLive) {
      final Widget liveBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_rounded, color: Colors.green.shade600, size: 19),
            const SizedBox(width: 7),
            Text(
              'به‌روزرسانی زنده',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

      return isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [searchField, const SizedBox(height: 10), liveBadge],
            )
          : Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                liveBadge,
              ],
            );
    }

    final Widget periodField = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _period,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          onChanged: (String? value) {
            if (value == null || value == _period) return;

            setState(() {
              _period = value;
            });

            _loadPage(reset: true);
          },
          items: const [
            DropdownMenuItem(value: 'all', child: Text('همهٔ زمان‌ها')),
            DropdownMenuItem(value: 'today', child: Text('امروز')),
            DropdownMenuItem(value: 'week', child: Text('۷ روز اخیر')),
            DropdownMenuItem(value: 'month', child: Text('۳۰ روز اخیر')),
          ],
        ),
      ),
    );

    final Widget refreshButton = SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : () => _loadPage(reset: true),
        icon: const Icon(Icons.refresh_rounded, size: 19),
        label: const Text('به‌روزرسانی'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              periodField,
              const SizedBox(height: 10),
              refreshButton,
            ],
          )
        : Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 190, child: periodField),
              const SizedBox(width: 12),
              refreshButton,
            ],
          );
  }

  Widget _buildLiveBody(bool isMobile) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activeStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStateBox(
            icon: Icons.error_outline_rounded,
            color: Colors.red.shade600,
            message: _friendlyError(snapshot.error.toString()),
            selectable: true,
          );
        }

        if (!snapshot.hasData) {
          return _buildLoadingBox();
        }

        final List<_TripItem> items = snapshot.data!.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                _TripItem.fromDoc(d))
            .toList();

        return _buildList(items, isMobile, showLoadMore: false);
      },
    );
  }

  Widget _buildPagedBody(bool isMobile) {
    if (_error != null && _docs.isEmpty) {
      return _buildStateBox(
        icon: Icons.error_outline_rounded,
        color: Colors.red.shade600,
        message: _friendlyError(_error!),
        selectable: true,
      );
    }

    if (_isLoading && _docs.isEmpty) {
      return _buildLoadingBox();
    }

    final List<_TripItem> items = _docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            _TripItem.fromDoc(d))
        .toList();

    return _buildList(items, isMobile, showLoadMore: true);
  }

  Widget _buildList(
    List<_TripItem> allItems,
    bool isMobile, {
    required bool showLoadMore,
  }) {
    final String q = _query.toLowerCase();

    final List<_TripItem> items = q.isEmpty
        ? allItems
        : allItems.where((_TripItem item) => item.matches(q)).toList();

    if (allItems.isEmpty) {
      return _buildStateBox(
        icon: Icons.route_outlined,
        color: Colors.grey.shade500,
        message: _emptyMessage(),
      );
    }

    if (items.isEmpty) {
      return Column(
        children: [
          _buildStateBox(
            icon: Icons.search_off_rounded,
            color: Colors.grey.shade500,
            message: 'نتیجه‌ای در سفرهای بارگذاری‌شده پیدا نشد',
          ),
          if (showLoadMore && _hasMore) ...[
            const SizedBox(height: 12),
            _buildLoadMoreButton(),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummary(items),
        const SizedBox(height: 12),
        isMobile ? _buildCards(items) : _buildTable(items),
        if (showLoadMore && _hasMore) ...[
          const SizedBox(height: 14),
          _buildLoadMoreButton(),
        ],
        if (showLoadMore && _error != null) ...[
          const SizedBox(height: 10),
          Text(
            _friendlyError(_error!),
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _emptyMessage() {
    switch (widget.group) {
      case _TripGroup.active:
        return 'الان هیچ سفر فعالی وجود ندارد';
      case _TripGroup.completed:
        return 'سفر انجام‌شده‌ای در این بازه پیدا نشد';
      case _TripGroup.cancelled:
        return 'سفر لغوشده‌ای در این بازه پیدا نشد';
    }
  }

  Widget _buildSummary(List<_TripItem> items) {
    final List<String> parts = <String>[
      '${AdminFormat.toFa(items.length)} سفر',
    ];

    if (widget.group == _TripGroup.completed) {
      final double totalFare =
          items.fold<double>(0, (double s, _TripItem i) => s + i.fare);
      final double totalCommission = items.fold<double>(
        0,
        (double s, _TripItem i) => s + (i.commission ?? 0),
      );

      parts.add('کل کرایه: ${AdminFormat.money(totalFare)} افغانی');
      parts.add('کل کمیسیون: ${AdminFormat.money(totalCommission)} افغانی');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parts
          .map(
            (String text) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLoadMoreButton() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : () => _loadPage(),
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(Icons.expand_more_rounded),
        label: Text(_isLoading ? 'در حال بارگذاری...' : 'بارگذاری سفرهای بیشتر'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ───────── جدول (دسکتاپ) ─────────

  List<_Col> _columns() {
    final _Col code = _Col('کد سفر', 7, (_TripItem i) => _codeCell(i));
    final _Col date = _Col('تاریخ', 12, (_TripItem i) => _dateCell(i));
    final _Col passenger = _Col(
      'مسافر',
      11,
      (_TripItem i) => _textCell(i.passengerName),
    );
    final _Col driver = _Col(
      'راننده',
      11,
      (_TripItem i) => _textCell(i.driverName),
    );
    final _Col origin = _Col('مبدأ', 15, (_TripItem i) => _textCell(i.origin));
    final _Col destination = _Col(
      'مقصد',
      15,
      (_TripItem i) => _textCell(i.destination),
    );
    final _Col fare = _Col(
      'کرایه',
      9,
      (_TripItem i) => _moneyCell(i.fare),
    );

    switch (widget.group) {
      case _TripGroup.active:
        return <_Col>[
          code,
          date,
          passenger,
          driver,
          origin,
          destination,
          fare,
          _Col('وضعیت', 12, (_TripItem i) => _statusChip(i)),
        ];
      case _TripGroup.completed:
        return <_Col>[
          code,
          date,
          passenger,
          driver,
          origin,
          destination,
          _Col(
            'مسافت',
            8,
            (_TripItem i) => _textCell(
              i.distanceKm == null ? '--' : AdminFormat.kilometers(i.distanceKm!),
            ),
          ),
          fare,
          _Col(
            'کمیسیون',
            9,
            (_TripItem i) =>
                i.commission == null ? _textCell('--') : _moneyCell(i.commission!),
          ),
          _Col('وضعیت کمیسیون', 11, (_TripItem i) => _commissionChip(i)),
        ];
      case _TripGroup.cancelled:
        return <_Col>[
          code,
          date,
          passenger,
          driver,
          origin,
          destination,
          fare,
          _Col('وضعیت', 13, (_TripItem i) => _statusChip(i)),
        ];
    }
  }

  Widget _buildTable(List<_TripItem> items) {
    final List<_Col> columns = _columns();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1250,
            child: Column(
              children: [
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.82),
                      ],
                    ),
                  ),
                  child: Row(
                    children: columns
                        .map(
                          (_Col c) => Expanded(
                            flex: c.flex,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                c.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final _TripItem item = items[index];

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openDetails(item),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 66),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: columns
                              .map(
                                (_Col c) => Expanded(
                                  flex: c.flex,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    child: c.cell(item),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────── کارت (موبایل) ─────────

  Widget _buildCards(List<_TripItem> items) {
    return Column(
      children: items
          .map(
            (_TripItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openDetails(item),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _codeCell(item),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _displayDateText(item),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          _statusChip(item),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _mobileRow(Icons.person_outline_rounded, 'مسافر', item.passengerName),
                      const SizedBox(height: 8),
                      _mobileRow(Icons.local_taxi_outlined, 'راننده', item.driverName),
                      const SizedBox(height: 8),
                      _mobileRow(Icons.trip_origin_rounded, 'مبدأ', item.origin),
                      const SizedBox(height: 8),
                      _mobileRow(Icons.location_on_outlined, 'مقصد', item.destination),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: Colors.grey.shade500,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'کرایه',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          _moneyCell(item.fare),
                        ],
                      ),
                      if (widget.group == _TripGroup.completed) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.percent_rounded,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'کمیسیون',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            if (item.commission != null) ...[
                              _moneyCell(item.commission!),
                              const SizedBox(width: 8),
                            ],
                            _commissionChip(item),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _mobileRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ───────── سلول‌ها ─────────

  Widget _codeCell(_TripItem item) {
    final String shortId =
        item.id.length > 6 ? item.id.substring(0, 6) : item.id;

    return Tooltip(
      message: item.id,
      child: Text(
        shortId,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _displayDateText(_TripItem item) {
    final DateTime? date = item.displayDate(widget.group);
    return date == null ? '--' : AdminFormat.jalaliDateTime(date);
  }

  Widget _dateCell(_TripItem item) {
    return Center(
      child: Text(
        _displayDateText(item),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
      ),
    );
  }

  Widget _textCell(String value) {
    return Center(
      child: Text(
        value,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
      ),
    );
  }

  Widget _moneyCell(double value) {
    return Center(
      child: Text(
        '${AdminFormat.money(value)} افغانی',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusChip(_TripItem item) {
    final Color color = item.statusColor;

    return _chip(
      text: item.statusText,
      color: color,
      icon: item.statusIcon,
    );
  }

  Widget _commissionChip(_TripItem item) {
    switch (item.commissionStatus) {
      case 'settled':
        return _chip(
          text: 'تصفیه‌شده',
          color: Colors.green,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'unpaid':
        return _chip(
          text: 'پرداخت‌نشده',
          color: Colors.orange.shade800,
          icon: Icons.hourglass_bottom_rounded,
        );
      default:
        return _chip(
          text: 'ثبت‌نشده',
          color: Colors.grey,
          icon: Icons.help_outline_rounded,
        );
    }
  }

  Widget _chip({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── وضعیت‌ها و پیام‌ها ─────────

  Widget _buildLoadingBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: _cardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildStateBox({
    required IconData icon,
    required Color color,
    required String message,
    bool selectable = false,
  }) {
    final TextStyle style = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 13,
      height: 1.6,
    );

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

  /// خطای ایندکس را با راهنمای فارسی نشان می‌دهد
  String _friendlyError(String error) {
    final String lower = error.toLowerCase();

    if (lower.contains('index')) {
      return 'برای این فهرست باید یک «ایندکس» در Firestore ساخته شود.\n'
          'در Firebase Console بخش Firestore ← Indexes ← Add index:\n'
          'کلکسیون rides، فیلد status (Ascending) و فیلد createdAt (Descending).\n'
          'یا روی لینکی که در متن خطای زیر می‌بینید بزنید.\n\n$error';
    }

    if (lower.contains('permission')) {
      return 'اجازهٔ خواندن سفرها وجود ندارد. قوانین Firestore و نقش ادمین را بررسی کنید.\n\n$error';
    }

    return 'خطا در دریافت اطلاعات سفرها:\n$error';
  }

  // ════════════════════════════════════════════════════════════
  //  جزئیات سفر و لغو توسط ادمین
  // ════════════════════════════════════════════════════════════

  void _openDetails(_TripItem item) {
    final List<MapEntry<String, String>> rows = item.detailRows();
    final bool canAdminCancel = item.isActiveStatus;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'جزئیات سفر',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows
                    .map(
                      (MapEntry<String, String> row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(
                                row.key,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                row.value,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            if (canAdminCancel)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _adminCancel(item);
                },
                icon: const Icon(Icons.block_rounded, color: Colors.red),
                label: const Text(
                  'لغو سفر توسط ادمین',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  /// برای سفرهای گیرکرده (مثلاً راننده‌ای پیدا نشده یا برنامه بسته شده)
  Future<void> _adminCancel(_TripItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('لغو سفر'),
          content: Text(
            'سفر ${item.id.length > 6 ? item.id.substring(0, 6) : item.id} '
            'برای مسافر و راننده لغو می‌شود. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('لغو سفر'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await item.ref.update(<String, dynamic>{
        'status': 'cancelled',
        'cancelled_by': 'admin',
        'cancelled_by_admin_id': FirebaseAuth.instance.currentUser?.uid ?? '',
        'cancel_reason': 'admin_cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سفر لغو شد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لغو سفر انجام نشد: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  ستون جدول
// ════════════════════════════════════════════════════════════

class _Col {
  final String title;
  final int flex;
  final Widget Function(_TripItem item) cell;

  const _Col(this.title, this.flex, this.cell);
}

// ════════════════════════════════════════════════════════════
//  مدل نمایشی یک سفر
// ════════════════════════════════════════════════════════════

String _readText(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final Object? value = data[key];

    if (value == null) continue;

    if (value is String) {
      final String text = value.trim();
      if (text.isNotEmpty) return text;
      continue;
    }

    if (value is num || value is bool) return value.toString();

    if (value is Map) {
      for (final String sub in const <String>[
        'address',
        'name',
        'title',
        'value',
        'text',
      ]) {
        final Object? nested = value[sub];

        if (nested != null && nested.toString().trim().isNotEmpty) {
          return nested.toString().trim();
        }
      }
    }
  }

  return fallback;
}

String _normalizeStatus(String value) {
  return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
}

class _TripItem {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;

  final DateTime? createdAt;
  final String passengerName;
  final String driverName;
  final String origin;
  final String destination;
  final double fare;
  final double? commission;
  final double? driverEarnings;
  final double? distanceKm;
  final String status;
  final String commissionStatus;

  const _TripItem({
    required this.id,
    required this.ref,
    required this.data,
    required this.createdAt,
    required this.passengerName,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.fare,
    required this.commission,
    required this.driverEarnings,
    required this.distanceKm,
    required this.status,
    required this.commissionStatus,
  });

  factory _TripItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();

    final String driverId = _readText(data, <String>['driver_id', 'driverId']);

    String driverName = _readText(
      data,
      <String>['driver_name', 'driverName', 'drivername'],
    );

    if (driverName.isEmpty) {
      driverName = driverId == 'waiting' || driverId.isEmpty
          ? 'در انتظار راننده'
          : 'نامشخص';
    }

    final double? distance = AdminFormat.toNumber(
      data['distance'] ?? data['distanceKm'] ?? data['distanceInKm'],
    );

    return _TripItem(
      id: doc.id,
      ref: doc.reference,
      data: data,
      createdAt: AdminFormat.readDate(
        data['createdAt'] ?? data['created_at'],
      ),
      passengerName: _readText(
        data,
        <String>[
          'passenger_name',
          'passengerName',
          'passengername',
          'userName',
          'username',
          'user_name',
        ],
        fallback: 'نامشخص',
      ),
      driverName: driverName,
      origin: _readText(
        data,
        <String>[
          'originAddress',
          'origin_address',
          'originaddress',
          'pickup_address',
          'pickupAddress',
          'origin',
        ],
        fallback: '-',
      ),
      destination: _readText(
        data,
        <String>[
          'destinationAddress',
          'destination_address',
          'destinationaddress',
          'dropoff_address',
          'dropoffAddress',
          'destination',
        ],
        fallback: '-',
      ),
      fare: AdminFormat.toNumber(
            data['total_fare'] ??
                data['fareAmount'] ??
                data['fare_amount'] ??
                data['fare'] ??
                data['price'] ??
                data['amount'],
          ) ??
          0,
      commission: AdminFormat.toNumber(data['commission_amount']),
      driverEarnings: AdminFormat.toNumber(data['driver_earnings']),
      distanceKm: distance != null && distance > 0 ? distance : null,
      status: _normalizeStatus(_readText(data, <String>['status'])),
      commissionStatus: _readText(data, <String>['commission_status']).toLowerCase(),
    );
  }

  bool get isActiveStatus =>
      status == 'searching' ||
      status == 'accepted' ||
      status == 'arrived' ||
      status == 'ontrip' ||
      status == 'on_trip';

  bool get isStaleSearching =>
      status == 'searching' &&
      createdAt != null &&
      DateTime.now().difference(createdAt!) > _searchExpiry;

  /// تاریخ نمایش: برای انجام‌شده زمان پایان، برای لغوشده زمان لغو
  DateTime? displayDate(_TripGroup group) {
    switch (group) {
      case _TripGroup.completed:
        return AdminFormat.readDate(data['completed_at'] ?? data['completedAt']) ??
            createdAt;
      case _TripGroup.cancelled:
        return AdminFormat.readDate(data['cancelled_at'] ?? data['cancelledAt']) ??
            createdAt;
      case _TripGroup.active:
        return createdAt;
    }
  }

  bool matches(String lowerQuery) {
    return id.toLowerCase().contains(lowerQuery) ||
        passengerName.toLowerCase().contains(lowerQuery) ||
        driverName.toLowerCase().contains(lowerQuery) ||
        origin.toLowerCase().contains(lowerQuery) ||
        destination.toLowerCase().contains(lowerQuery) ||
        _readText(data, <String>['passenger_phone', 'userPhone'])
            .toLowerCase()
            .contains(lowerQuery) ||
        _readText(data, <String>['driver_phone', 'driverPhone'])
            .toLowerCase()
            .contains(lowerQuery);
  }

  String get statusText {
    final String cancelledBy =
        _readText(data, <String>['cancelled_by']).toLowerCase();
    final String reason = _readText(data, <String>['cancel_reason']);

    switch (status) {
      case 'searching':
        return isStaleSearching ? 'منقضی (راننده پیدا نشد)' : 'در انتظار راننده';
      case 'accepted':
        return 'پذیرفته‌شده';
      case 'arrived':
        return 'راننده در مبدأ';
      case 'ontrip':
      case 'on_trip':
        return 'در حال سفر';
      case 'completed':
      case 'ended':
        return 'پایان‌یافته';
      case 'cancelled_by_driver':
        return 'لغو توسط راننده';
      case 'cancelled_by_passenger':
        return reason == 'no_driver_found'
            ? 'منقضی (راننده پیدا نشد)'
            : 'لغو توسط مسافر';
      case 'cancelled':
        return cancelledBy == 'admin' ? 'لغو توسط ادمین' : 'لغوشده';
      default:
        return status.isEmpty ? 'نامشخص' : status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'searching':
        return isStaleSearching ? Colors.red : Colors.orange.shade800;
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.deepPurple;
      case 'ontrip':
      case 'on_trip':
        return Colors.indigo;
      case 'completed':
      case 'ended':
        return Colors.green;
      case 'cancelled_by_driver':
      case 'cancelled_by_passenger':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'searching':
        return isStaleSearching ? Icons.timer_off_outlined : Icons.search_rounded;
      case 'accepted':
        return Icons.thumb_up_alt_outlined;
      case 'arrived':
        return Icons.place_outlined;
      case 'ontrip':
      case 'on_trip':
        return Icons.navigation_rounded;
      case 'completed':
      case 'ended':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.cancel_outlined;
    }
  }

  /// ردیف‌های پنجرهٔ جزئیات
  List<MapEntry<String, String>> detailRows() {
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[];

    void add(String title, String value) {
      if (value.trim().isEmpty) return;
      rows.add(MapEntry<String, String>(title, value));
    }

    final String passengerPhone =
        _readText(data, <String>['passenger_phone', 'userPhone']);
    final String driverPhone =
        _readText(data, <String>['driver_phone', 'driverPhone']);

    add('کد سفر', id);
    add('وضعیت', statusText);
    add('تاریخ ثبت', createdAt == null ? '' : AdminFormat.jalaliDateTime(createdAt!));
    add(
      'مسافر',
      passengerPhone.isEmpty ? passengerName : '$passengerName\n$passengerPhone',
    );
    add(
      'راننده',
      driverPhone.isEmpty ? driverName : '$driverName\n$driverPhone',
    );
    add('خودرو', _readText(data, <String>['car_details', 'carDetails']));
    add('پلاک', _readText(data, <String>['car_number', 'carNumber']));
    add('مبدأ', origin);
    add('مقصد', destination);
    add('مسافت', distanceKm == null ? '' : AdminFormat.kilometers(distanceKm!));
    add('کرایه', '${AdminFormat.money(fare)} افغانی');

    if (commission != null) {
      add('کمیسیون', '${AdminFormat.money(commission!)} افغانی');
    }

    if (driverEarnings != null) {
      add('سهم راننده', '${AdminFormat.money(driverEarnings!)} افغانی');
    }

    if (commissionStatus.isNotEmpty) {
      add(
        'وضعیت کمیسیون',
        commissionStatus == 'settled' ? 'تصفیه‌شده' : 'پرداخت‌نشده',
      );
    }

    final DateTime? settledAt = AdminFormat.readDate(data['commission_settled_at']);
    if (settledAt != null) {
      add('زمان تصفیه', AdminFormat.jalaliDateTime(settledAt));
    }

    final String service = _readText(data, <String>['service_type']);
    final String vehicle = _readText(data, <String>['vehicle_type']);
    add('نوع سرویس', vehicle.isEmpty ? service : '$service / $vehicle');

    if (service == 'cargo') {
      add('خودروی باربری', _readText(data, <String>['cargo_vehicle']));
      add('نوع بار', _readText(data, <String>['cargo_package_type']));
      add('بیمه', _readText(data, <String>['cargo_insurance']));
      add('پرداخت‌کننده', _readText(data, <String>['cargo_payer']));
      add(
        'فرستنده',
        '${_readText(data, <String>['cargo_sender_name'])}\n'
            '${_readText(data, <String>['cargo_sender_phone'])}',
      );
      add(
        'گیرنده',
        '${_readText(data, <String>['cargo_receiver_name'])}\n'
            '${_readText(data, <String>['cargo_receiver_phone'])}',
      );
    }

    if (service == 'intercity') {
      final DateTime? travelDate = AdminFormat.readDate(data['intercity_date']);
      add('تاریخ حرکت', travelDate == null ? '' : AdminFormat.jalaliDate(travelDate));
      add(
        'تعداد مسافر',
        AdminFormat.toFa(_readText(data, <String>['intercity_passengers'])),
      );
    }

    final String cancelReason =
        _readText(data, <String>['cancel_reason', 'cancelReason']);
    add('دلیل لغو', cancelReason);

    final double? rating = AdminFormat.toNumber(data['passengerRating']);
    if (rating != null) {
      add('امتیاز مسافر', AdminFormat.toFa(rating.toStringAsFixed(0)));
    }

    return rows;
  }
}
