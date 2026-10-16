import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_admin/constants/app_colors.dart';

class StaffPage extends StatefulWidget {
  static const String id = 'staff';

  final String role;

  const StaffPage({
    super.key,
    required this.role,
  });

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';

  CollectionReference<Map<String, dynamic>> get _adminsCollection =>
      _firestore.collection('admins');

  bool get _isSuperAdmin => widget.role == 'superAdmin';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperAdmin) {
      return _buildAccessDenied();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 760;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 22),
                _buildSearchBar(isMobile),
                const SizedBox(height: 18),
                _buildStaffStream(isMobile),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 58,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 14),
              const Text(
                'دسترسی ندارید',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'این بخش فقط برای مدیر اصلی قابل دسترسی است.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final title = 'مدیریت کارمندان';
    final subtitle =
        'افزودن، ویرایش و کنترل دسترسی کارمندان پنل';

    final addButton = ElevatedButton.icon(
      onPressed: _showAddStaffDialog,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('افزودن کارمند'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderText(title, subtitle),
                const SizedBox(height: 18),
                addButton,
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildHeaderText(title, subtitle),
                ),
                addButton,
              ],
            ),
    );
  }

  Widget _buildHeaderText(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.manage_accounts_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 4,
      ),
      decoration: _cardDecoration(),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'جستجو بر اساس نام، ایمیل یا نقش...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.clear_rounded),
                ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildStaffStream(bool isMobile) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _adminsCollection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard(
            'خطا در دریافت کارمندان:
${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        final documents = snapshot.data?.docs ?? [];

        final filteredDocuments = documents.where((document) {
          final data = document.data();

          final name = _readValue(
            data,
            ['name', 'fullName', 'displayName', 'username'],
          );

          final email = _readValue(
            data,
            ['email'],
          );

          final role = _readValue(
            data,
            ['role'],
          );

          final searchValues = [
            document.id,
            name,
            email,
            role,
          ].join(' ').toLowerCase();

          return searchValues.contains(_searchText);
        }).toList();

        filteredDocuments.sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final aName = _readValue(
            aData,
            ['name', 'fullName', 'displayName', 'email'],
          ).toLowerCase();

          final bName = _readValue(
            bData,
            ['name', 'fullName', 'displayName', 'email'],
          ).toLowerCase();

          return aName.compareTo(bName);
        });

        if (filteredDocuments.isEmpty) {
          return _buildEmptyCard(
            hasSearch: _searchText.isNotEmpty,
          );
        }

        return _buildStaffContent(
          documents: filteredDocuments,
          isMobile: isMobile,
        );
      },
    );
  }

  Widget _buildStaffContent({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
        documents,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        children: documents
            .map(
              (document) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildStaffCard(document),
              ),
            )
            .toList(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          headingRowColor: WidgetStatePropertyAll(
            AppColors.primary.withOpacity(0.06),
          ),
          columns: const [
            DataColumn(label: Text('کارمند')),
            DataColumn(label: Text('نقش')),
            DataColumn(label: Text('بخش‌ها')),
            DataColumn(label: Text('وضعیت')),
            DataColumn(label: Text('عملیات')),
          ],
          rows: documents
              .map(
                (document) => _buildDataRow(document),
              )
              .toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final name = _staffName(data);
    final email = _readValue(data, ['email']);
    final role = _readValue(data, ['role']);
    final isActive = _readBool(data, 'active', fallback: true);
    final sections = _readSections(data);

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 210,
            child: Row(
              children: [
                _buildAvatar(name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(_buildRoleChip(role)),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              sections.isEmpty ? 'بدون بخش' : sections.join('، '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(_buildStatusChip(isActive)),
        DataCell(
          _buildActionsMenu(
            document: document,
            isActive: isActive,
          ),
        ),
      ],
    );
  }

  Widget _buildStaffCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final name = _staffName(data);
    final email = _readValue(data, ['email']);
    final role = _readValue(data, ['role']);
    final isActive = _readBool(data, 'active', fallback: true);
    final sections = _readSections(data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(name),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              _buildActionsMenu(
                document: document,
                isActive: isActive,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoleChip(role),
              _buildStatusChip(isActive),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'بخش‌های مجاز',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sections.isEmpty ? 'بدون بخش' : sections.join('، '),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsMenu({
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required bool isActive,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'عملیات',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showEditStaffDialog(document);
            break;
          case 'toggle':
            _toggleStaffStatus(document, isActive);
            break;
          case 'reset':
            _sendPasswordReset(document);
            break;
          case 'delete':
            _confirmDeleteStaff(document);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('ویرایش دسترسی'),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isActive
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            title: Text(
              isActive ? 'غیرفعال‌کردن' : 'فعال‌کردن',
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'reset',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_reset_outlined),
            title: Text('ارسال ایمیل تغییر رمز'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            title: Text(
              'حذف سند کارمند',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddStaffDialog() async {
    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) {
        return _StaffFormDialog(
          title: 'افزودن کارمند',
          submitText: 'افزودن',
        );
      },
    );

    if (result == null || !mounted) return;

    await _createStaffDocument(result);
  }

  Future<void> _showEditStaffDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final currentSections = _readSections(data);

    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) {
        return _StaffFormDialog(
          title: 'ویرایش دسترسی کارمند',
          submitText: 'ذخیره',
          initialName: _staffName(data),
          initialEmail: _readValue(data, ['email']),
          initialRole: _readValue(data, ['role']),
          initialSections: currentSections,
        );
      },
    );

    if (result == null || !mounted) return;

    await _updateStaffDocument(document, result);
  }

  Future<void> _createStaffDocument(
    _StaffFormResult result,
  ) async {
    final email = result.email.trim().toLowerCase();

    if (email.isEmpty) {
      _showSnackBar(
        'ایمیل کارمند وارد نشده است.',
        isError: true,
      );
      return;
    }

    final existing = await _adminsCollection
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      _showSnackBar(
        'این ایمیل قبلاً در کارمندان ثبت شده است.',
        isError: true,
      );
      return;
    }

    final docRef = _adminsCollection.doc();

    await docRef.set({
      'name': result.name.trim(),
      'email': email,
      'role': result.role,
      'allowSelection': result.sections,
      'allowedSections': result.sections,
      'permissions': _buildPermissions(result.sections),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
    });

    if (!mounted) return;

    _showSnackBar('سند کارمند با موفقیت ساخته شد.');
  }

  Future<void> _updateStaffDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    _StaffFormResult result,
  ) async {
    await document.reference.update({
      'name': result.name.trim(),
      'email': result.email.trim().toLowerCase(),
      'role': result.role,
      'allowSelection': result.sections,
      'allowedSections': result.sections,
      'permissions': _buildPermissions(result.sections),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    _showSnackBar('اطلاعات کارمند به‌روزرسانی شد.');
  }

  Future<void> _toggleStaffStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    bool currentStatus,
  ) async {
    if (document.id == _auth.currentUser?.uid) {
      _showSnackBar(
        'نمی‌توانید حساب خودتان را غیرفعال کنید.',
        isError: true,
      );
      return;
    }

    await document.reference.update({
      'active': !currentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    _showSnackBar(
      currentStatus
          ? 'کارمند غیرفعال شد.'
          : 'کارمند فعال شد.',
    );
  }

  Future<void> _sendPasswordReset(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final email = _readValue(
      document.data(),
      ['email'],
    );

    if (email.isEmpty) {
      _showSnackBar(
        'برای این کارمند ایمیل ثبت نشده است.',
        isError: true,
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      _showSnackBar(
        'ایمیل تغییر رمز ارسال شد.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showSnackBar(
        'خطا در ارسال ایمیل: ${error.message ?? error.code}',
        isError: true,
      );
    }
  }

  Future<void> _confirmDeleteStaff(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (document.id == _auth.currentUser?.uid) {
      _showSnackBar(
        'نمی‌توانید حساب خودتان را حذف کنید.',
        isError: true,
      );
      return;
    }

    final name = _staffName(document.data());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف کارمند'),
          content: Text(
            'آیا از حذف سند «$name» مطمئن هستید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await document.reference.delete();

    if (!mounted) return;

    _showSnackBar('سند کارمند حذف شد.');
  }

  Map<String, dynamic> _buildPermissions(
    List<String> sections,
  ) {
    final permissions = <String, dynamic>{};

    for (final section in sections) {
      permissions['$section.view'] = true;
      permissions['$section.create'] = true;
      permissions['$section.update'] = true;
      permissions['$section.delete'] = false;
    }

    return permissions;
  }

  String _staffName(Map<String, dynamic> data) {
    final name = _readValue(
      data,
      ['name', 'fullName', 'displayName', 'username'],
    );

    return name.isEmpty ? 'بدون نام' : name;
  }

  String _readValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  bool _readBool(
    Map<String, dynamic> data,
    String key, {
    required bool fallback,
  }) {
    final value = data[key];

    if (value is bool) return value;

    return fallback;
  }

  List<String> _readSections(
    Map<String, dynamic> data,
  ) {
    final value = data['allowedSections'] ??
        data['allowSelection'];

    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      if (value == 'all') {
        return ['همهٔ بخش‌ها'];
      }

      return [value];
    }

    return [];
  }

  Widget _buildAvatar(String name) {
    final firstLetter = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1);

    return CircleAvatar(
      radius: 21,
      backgroundColor: AppColors.primary.withOpacity(0.11),
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final label = role.isEmpty ? 'بدون نقش' : role;

    return Chip(
      avatar: const Icon(
        Icons.badge_outlined,
        size: 16,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.primary.withOpacity(0.08),
      side: BorderSide.none,
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Chip(
      avatar: Icon(
        isActive
            ? Icons.check_circle_outline
            : Icons.pause_circle_outline,
        size: 16,
        color: isActive ? Colors.green : Colors.orange,
      ),
      label: Text(
        isActive ? 'فعال' : 'غیرفعال',
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: isActive
          ? Colors.green.withOpacity(0.10)
          : Colors.orange.withOpacity(0.10),
      side: BorderSide.none,
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(45),
      decoration: _cardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: SelectableText(
        message,
        style: TextStyle(
          color: Colors.red.shade800,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required bool hasSearch,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(38),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'نتیجه‌ای پیدا نشد.'
                : 'هنوز کارمندی ثبت نشده است.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.grey.shade100,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

class _StaffFormResult {
  final String name;
  final String email;
  final String role;
  final List<String> sections;

  const _StaffFormResult({
    required this.name,
    required this.email,
    required this.role,
    required this.sections,
  });
}

class _StaffFormDialog extends StatefulWidget {
  final String title;
  final String submitText;
  final String initialName;
  final String initialEmail;
  final String initialRole;
  final List<String> initialSections;

  const _StaffFormDialog({
    required this.title,
    required this.submitText,
    this.initialName = '',
    this.initialEmail = '',
    this.initialRole = 'support',
    this.initialSections = const [],
  });

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  late String _selectedRole;
  late Set<String> _selectedSections;

  final List<_StaffRoleOption> _roles = const [
    _StaffRoleOption(
      value: 'drivers',
      label: 'مدیریت رانندگان',
      section: 'drivers',
    ),
    _StaffRoleOption(
      value: 'passengers',
      label: 'مدیریت مسافران',
      section: 'users',
    ),
    _StaffRoleOption(
      value: 'operations',
      label: 'مدیریت سفرها',
      section: 'trips',
    ),
    _StaffRoleOption(
      value: 'support',
      label: 'پشتیبانی',
      section: 'support',
    ),
    _StaffRoleOption(
      value: 'finance',
      label: 'مالی',
      section: 'finance',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.initialName,
    );

    _emailController = TextEditingController(
      text: widget.initialEmail,
    );

    _selectedRole = _roles.any(
      (item) => item.value == widget.initialRole,
    )
        ? widget.initialRole
        : 'support';

    _selectedSections = widget.initialSections.toSet();

    if (_selectedSections.isEmpty) {
      _selectedSections = {
        _sectionForRole(_selectedRole),
      };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _sectionForRole(String role) {
    switch (role) {
      case 'drivers':
        return 'drivers';
      case 'passengers':
        return 'users';
      case 'operations':
        return 'trips';
      case 'support':
        return 'support';
      case 'finance':
        return 'commission';
      default:
        return 'support';
    }
  }

  void _changeRole(String? value) {
    if (value == null) return;

    setState(() {
      _selectedRole = value;

      if (_selectedRole == 'finance') {
        _selectedSections = {
          'commission',
          'fare',
        };
      } else {
        _selectedSections = {
          _sectionForRole(_selectedRole),
        };
      }
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();

    if (name.isEmpty) {
      _showError('نام کارمند را وارد کنید.');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showError('ایمیل معتبر وارد کنید.');
      return;
    }

    final sections = _selectedSections.toList();

    if (sections.isEmpty) {
      _showError('حداقل یک بخش را انتخاب کنید.');
      return;
    }

    Navigator.of(context).pop(
      _StaffFormResult(
        name: name,
        email: email,
        role: _selectedRole,
        sections: sections,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'نام کارمند',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'ایمیل ورود',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'نقش کارمند',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role.value,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: _changeRole,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'بخش‌های مجاز',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ..._buildSectionCheckboxes(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.submitText),
        ),
      ],
    );
  }

  List<Widget> _buildSectionCheckboxes() {
    const sections = <Map<String, String>>[
      {
        'key': 'dashboard',
        'label': 'داشبورد',
      },
      {
        'key': 'drivers',
        'label': 'رانندگان',
      },
      {
        'key': 'users',
        'label': 'مسافران',
      },
      {
        'key': 'trips',
        'label': 'سفرها',
      },
      {
        'key': 'support',
        'label': 'پشتیبانی',
      },
      {
        'key': 'commission',
        'label': 'کمیسیون',
      },
      {
        'key': 'fare',
        'label': 'تنظیمات کرایه',
      },
    ];

    return sections.map((section) {
      final key = section['key']!;
      final label = section['label']!;

      return CheckboxListTile(
        value: _selectedSections.contains(key),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedSections.add(key);
            } else {
              _selectedSections.remove(key);
            }
          });
        },
      );
    }).toList();
  }
}

class _StaffRoleOption {
  final String value;
  final String label;
  final String section;

  const _StaffRoleOption({
    required this.value,
    required this.label,
    required this.section,
  });
}
