import 'package:flutter/material.dart';

import 'admin_sections.dart';
import 'database.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedSidebarIndex = 0;

  // Colors
  static const Color sidebarNavy = Color(0xFF091233);
  static const Color activeNavBg = Color(0xFF1B267E);

  final List<Map<String, dynamic>> _navItems = [
    {'title': 'Dashboard', 'icon': Icons.grid_view_rounded},
    {'title': 'Services', 'icon': Icons.layers_outlined},
    {'title': 'Counters', 'icon': Icons.computer_rounded},
    {'title': 'Staff', 'icon': Icons.people_outline_rounded},
    {'title': 'Manage Users', 'icon': Icons.manage_accounts_outlined},
    {'title': 'Queue History', 'icon': Icons.access_time_rounded},
    {'title': 'Reports', 'icon': Icons.bar_chart_rounded},
    {'title': 'Settings', 'icon': Icons.settings_outlined},
  ];

  void _logout() {
    Session.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  /// Rebuilds (and therefore reloads) the selected panel so its numbers are
  /// always read fresh from the database.
  Widget _buildSection() {
    switch (_selectedSidebarIndex) {
      case 1:
        return const AdminServicesSection();
      case 2:
        return const AdminCountersSection();
      case 3:
        return const AdminStaffSection();
      case 4:
        return const AdminUsersSection();
      case 5:
        return const AdminHistorySection();
      case 6:
        return const AdminReportsSection();
      case 7:
        return const AdminSettingsSection();
      default:
        return const AdminOverviewSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSectionBg,
      body: Row(
        children: [
          // ─── 1. LEFT SIDEBAR ────────────────────────────────
          Container(
            width: 230,
            color: sidebarNavy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),

                // Logo Brand
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: sidebarNavy,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SMARTQR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Navigation Items
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _navItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final isSelected = _selectedSidebarIndex == index;

                      return InkWell(
                        onTap: () =>
                            setState(() => _selectedSidebarIndex = index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? activeNavBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF8B98B8),
                                size: 19,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item['title'] as String,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF8B98B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Signed-in admin, so the sidebar reflects the real session.
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 16),
                  child: Text(
                    Session.fullName.isEmpty ? 'Admin' : Session.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Logout
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 28),
                  child: InkWell(
                    onTap: _logout,
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Color(0xFF8B98B8), size: 19),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B98B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. MAIN CONTENT AREA ───────────────────────────
          Expanded(child: _buildSection()),
        ],
      ),
    );
  }
}
