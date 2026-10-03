import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  static const String id = "webPageNotifications";
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  
  String _targetGroup = 'all'; // 'all', 'drivers', 'users'
  bool _isSending = false;

  // 🔄 متد جدید و پیشرفته ارسال اعلان به تمام کاربران و رانندگان
  Future<void> _sendNotification() async {
    String title = _titleController.text.trim();
    String body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("لطفاً عنوان و متن پیام را وارد کنید"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // ۱. ثبت در کلاکشن کلی notifications برای پنل ادمین
      DocumentReference globalNotifRef =
          FirebaseFirestore.instance.collection("notifications").doc();

      Map<String, dynamic> notifData = {
        "title": title,
        "body": body,
        "targetGroup": _targetGroup,
        "createdAt": FieldValue.serverTimestamp(),
        "isRead": false,
      };

      batch.set(globalNotifRef, notifData);

      // ۲. ثبت در کلاکشن کلی messages (پشتیبانی از ساختارهای دیگر)
      DocumentReference globalMsgRef =
          FirebaseFirestore.instance.collection("messages").doc();
      batch.set(globalMsgRef, notifData);

      // ۳. پخش پیام بر اساس گروه هدف (ارسال مستقیم به پروفایل تک‌تک رانندگان/مسافران)
      if (_targetGroup == 'all' || _targetGroup == 'drivers') {
        var driversSnapshot =
            await FirebaseFirestore.instance.collection("drivers").get();
        for (var doc in driversSnapshot.docs) {
          DocumentReference driverNotifRef = doc.reference
              .collection("notifications")
              .doc(globalNotifRef.id);
          batch.set(driverNotifRef, notifData);
        }
      }

      if (_targetGroup == 'all' || _targetGroup == 'users') {
        var usersSnapshot =
            await FirebaseFirestore.instance.collection("users").get();
        for (var doc in usersSnapshot.docs) {
          DocumentReference userNotifRef =
              doc.reference.collection("notifications").doc(globalNotifRef.id);
          batch.set(userNotifRef, notifData);
        }
      }

      // ۴. اجرای همزمان (Commit)
      await batch.commit();

      // ۵. ثبت در دیتابیس فعالیت‌های اخیر داشبورد
      String targetText = _targetGroup == 'drivers'
          ? 'رانندگان'
          : (_targetGroup == 'users' ? 'مسافران' : 'همه کاربران');

      await FirebaseFirestore.instance.collection("activities").add({
        "title": "ارسال اعلان عمومی",
        "subtitle": "ارسال پیام به $targetText: $title",
        "time": "هم‌اکنون",
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("پیام با موفقیت به تمام رانندگان و مسافران ارسال شد"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطا در ارسال پیام: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- HEADER ----------------
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مدیریت و ارسال اعلان‌ها',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ارسال پیام و اطلاع‌رسانی همگانی به رانندگان و مسافران سفیر',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ---------------- FORM SECTION ----------------
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ایجاد پیام جدید",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // انتخاب گیرندگان
                  Row(
                    children: [
                      const Text(
                        "گیرندگان پیام: ",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _targetGroup,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text("همه کاربران و رانندگان")),
                          DropdownMenuItem(value: 'drivers', child: Text("فقط رانندگان")),
                          DropdownMenuItem(value: 'users', child: Text("فقط مسافران")),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _targetGroup = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // کادر عنوان پیام
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: "عنوان پیام",
                      hintText: "مثال: تغییر در قوانین سفیر",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // کادر متن اصلی
                  TextField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: "متن پیام",
                      hintText: "متن کامل پیام اطلاع‌رسانی را اینجا بنویسید...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // دکمه ارسال
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendNotification,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(_isSending ? "در حال ارسال..." : "ارسال همگانی پیام"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ---------------- HISTORY LIST ----------------
            const Text(
              "تاریخچه پیام‌های ارسال شده",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("notifications")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "هنوز پیامی ارسال نشده است.",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.send, color: Colors.white, size: 18),
                        ),
                        title: Text(data["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(data["body"] ?? ""),
                        ),
                        trailing: Chip(
                          label: Text(
                            data["targetGroup"] == 'drivers'
                                ? 'رانندگان'
                                : (data["targetGroup"] == 'users' ? 'مسافران' : 'همه'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
