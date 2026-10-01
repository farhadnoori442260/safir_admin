import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safir_admin/constants/app_colors.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // 📍 Streamهای لایو آمار
  final Stream<QuerySnapshot> _driversStream =
      FirebaseFirestore.instance.collection("drivers").snapshots();

  final Stream<QuerySnapshot> _usersStream =
      FirebaseFirestore.instance.collection("users").snapshots();

  final Stream<QuerySnapshot> _allTripsStream =
      FirebaseFirestore.instance.collection("tripRequests").snapshots();

  // 📍 Stream زنده فعالیت‌های اخیر (آخرین ۱۰ فعالیت ثبت‌شده)
  final Stream<QuerySnapshot> _activitiesStream = FirebaseFirestore.instance
      .collection("activities")
      .orderBy("timestamp", descending: true)
      .limit(10)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final currentLocale = context.locale;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- HEADER / WELCOME ----------------
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'welcome_title'.tr(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'welcome_subtitle'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('refresh'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ---------------- STAT CARDS ----------------
            StreamBuilder<QuerySnapshot>(
              stream: _driversStream,
              builder: (context, driversSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _usersStream,
                  builder: (context, usersSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _allTripsStream,
                      builder: (context, tripsSnapshot) {
                        String driversCount = driversSnapshot.hasData
                            ? driversSnapshot.data!.docs.length.toString()
                            : "...";

                        String usersCount = usersSnapshot.hasData
                            ? usersSnapshot.data!.docs.length.toString()
                            : "...";

                        int activeTripsCount = 0;
                        int endedTripsCount = 0;

                        if (tripsSnapshot.hasData) {
                          for (var doc in tripsSnapshot.data!.docs) {
                            var status = doc.get("status");
                            if (status == "onTrip" || status == "accepted") {
                              activeTripsCount++;
                            } else if (status == "ended") {
                              endedTripsCount++;
                            }
                          }
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            double cardWidth = constraints.maxWidth > 900
                                ? (constraints.maxWidth - 48) / 4
                                : (constraints.maxWidth - 16) / 2;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _buildStatCard(
                                  width: cardWidth,
                                  title: 'total_drivers'.tr(),
                                  value: driversCount,
                                  icon: Icons.badge_outlined,
                                  color: AppColors.primary,
                                ),
                                _buildStatCard(
                                  width: cardWidth,
                                  title: 'active_trips'.tr(),
                                  value: tripsSnapshot.hasData
                                      ? activeTripsCount.toString()
                                      : "...",
                                  icon: Icons.local_taxi_outlined,
                                  color: Colors.orange,
                                ),
                                _buildStatCard(
                                  width: cardWidth,
                                  title: 'total_users'.tr(),
                                  value: usersCount,
                                  icon: Icons.people_outline,
                                  color: Colors.blue,
                                ),
                                _buildStatCard(
                                  width: cardWidth,
                                  title: 'completed_trips'.tr(),
                                  value: tripsSnapshot.hasData
                                      ? endedTripsCount.toString()
                                      : "...",
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),

            // ---------------- MAIN CONTENT AREA ----------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔄 فعالیت‌های اخیر (اتصال زنده به Firestore)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'recent_activity'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        StreamBuilder<QuerySnapshot>(
                          stream: _activitiesStream,
                          builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    "هیچ فعالیت جدیدی ثبت نشده است",
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                  ),
                                ),
                              );
                            }

                            var activities = snapshot.data!.docs;

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activities.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 20, thickness: 0.5),
                              itemBuilder: (context, index) {
                                var data = activities[index].data() as Map<String, dynamic>;
                                
                                String title = data["title"] ?? "فعالیت جدید";
                                String subtitle = data["subtitle"] ?? "";
                                String time = data["time"] ?? "";

                                return _buildActivityTile(title, subtitle, time);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // بنر وضعیت سیستم
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'system_status'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'system_status_desc'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(String title, String subtitle, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        Text(
          time,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
