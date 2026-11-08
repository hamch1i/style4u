
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_user_management_screen.dart';
import 'admin_seller_management_screen.dart';
import 'admin_seller_applications_screen.dart';
import 'admin_platform_settings_screen.dart';
import '../auth/web_login_screen.dart';

class AdminWebDashboard extends StatefulWidget {
  const AdminWebDashboard({super.key});

  @override
  State<AdminWebDashboard> createState() =>
      _AdminWebDashboardState();
}

class _AdminWebDashboardState extends State<AdminWebDashboard> {
  int selectedIndex = 0;

  static const Color pink = Color(0xFFD96B91);
  static const Color darkPink = Color(0xFFB94F78);

  final List<String> menuItems = [
    'Dashboard',
    'User Management',
    'Seller Management',
    'Seller Applications',
    'Platform Settings',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.store_outlined,
    Icons.assignment_outlined,
    Icons.settings_outlined,
  ];

  // --------------------------------------------------
  // PAGE NAVIGATION
  // --------------------------------------------------

  Widget _buildPage() {
    switch (selectedIndex) {
      case 1:
        return const AdminUserManagementScreen();
      case 2:
        return const AdminSellerManagementScreen();
      case 3:
        return const AdminSellerApplicationsScreen();
      case 4:
        return const AdminPlatformSettingsScreen();
      default:
        return _buildDashboardHome();
    }
  }

  // --------------------------------------------------
  // RESPONSIVE SIDEBAR
  // --------------------------------------------------

  Widget _buildSidebar({bool inDrawer = false}) {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 28),

          // LOGO AND APP NAME
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('AppSettings')
                .doc('platform')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data()
                  as Map<String, dynamic>?;

              final appName = data?['appName'] ?? 'Style4U';
              final logoUrl = data?['appLogoUrl'] as String?;

              return Column(
                children: [
                  _buildLogo(logoUrl),
                  const SizedBox(height: 10),
                  Text(
                    appName.toString(),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: darkPink,
                    ),
                  ),
                  const Text(
                    'ADMIN PANEL',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Colors.grey,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 35),

          // NAVIGATION MENU
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ListTile(
                    selected: selected,
                    selectedTileColor:
                        pink.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: Icon(
                      menuIcons[index],
                      color: selected ? darkPink : Colors.grey,
                    ),
                    title: Text(
                      menuItems[index],
                      style: TextStyle(
                        color: selected
                            ? darkPink
                            : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      if (inDrawer) {
                        Navigator.pop(context);
                      }

                      setState(() {
                        selectedIndex = index;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // LOGOUT
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              if (inDrawer) {
                Navigator.pop(context);
              }
              _logout();
            },
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // DASHBOARD HOME
  // --------------------------------------------------

  Widget _buildDashboardHome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        final horizontalPadding =
            screenWidth < 600 ? 16.0 : 28.0;

        final cardWidth = screenWidth < 500
            ? screenWidth - (horizontalPadding * 2)
            : screenWidth >= 1100
                ? 220.0
                : (screenWidth -
                    (horizontalPadding * 2) -
                    18) / 2;

        return SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: screenWidth < 600 ? 22 : 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Welcome to the Style4U administration panel.',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 28),

              // USER STATISTICS
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Unable to load user statistics.',
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final users = snapshot.data!.docs;

                  final buyers = users.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    return data['role'] == 'user' ||
                        data['role'] == 'buyer';
                  }).length;

                  final sellers = users.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    return data['role'] == 'seller';
                  }).length;

                  final admins = users.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    return data['role'] == 'admin';
                  }).length;

                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      _statCard(
                        'Total Users',
                        users.length.toString(),
                        Icons.people,
                        Colors.blue,
                        cardWidth,
                      ),

                      _statCard(
                        'Buyers',
                        buyers.toString(),
                        Icons.person_outline,
                        Colors.green,
                        cardWidth,
                      ),

                      _statCard(
                        'Sellers',
                        sellers.toString(),
                        Icons.store,
                        pink,
                        cardWidth,
                      ),

                      _statCard(
                        'Admins',
                        admins.toString(),
                        Icons.admin_panel_settings,
                        Colors.orange,
                        cardWidth,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 30),

              // PLATFORM STATUS
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('AppSettings')
                    .doc('platform')
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data()
                      as Map<String, dynamic>?;

                  final isActive = data?['isActive'] ?? true;
                  final appName =
                      data?['appName'] ?? 'Style4U';

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Platform Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text('Application: $appName'),

                        const SizedBox(height: 8),

                        Wrap(
                          crossAxisAlignment:
                              WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: isActive
                                  ? Colors.green
                                  : Colors.red,
                            ),

                            Text(
                              isActive
                                  ? 'Platform is Active'
                                  : 'Platform is Deactivated',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              // QUICK ACCESS BUTTONS
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _quickButton(
                    'Manage Users',
                    Icons.people,
                    () => _navigateTo(1),
                  ),

                  _quickButton(
                    'Manage Sellers',
                    Icons.store,
                    () => _navigateTo(2),
                  ),

                  _quickButton(
                    'Seller Applications',
                    Icons.assignment_outlined,
                    () => _navigateTo(3),
                  ),

                  _quickButton(
                    'Platform Settings',
                    Icons.settings,
                    () => _navigateTo(4),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // NAVIGATION HELPER
  // --------------------------------------------------

  void _navigateTo(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  // --------------------------------------------------
  // STATISTICS CARD
  // --------------------------------------------------

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // QUICK ACCESS BUTTON
  // --------------------------------------------------

  Widget _quickButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: darkPink,
        side: const BorderSide(color: pink),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
    );
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WebLoginScreen(),
      ),
      (route) => false,
    );
  }

  // --------------------------------------------------
  // LOGO WITH FIRESTORE OVERRIDE
  // --------------------------------------------------

  Widget _buildLogo(String? logoUrl) {
    Widget localLogo() {
      return Image.asset(
        'assets/images/style4u_logo.png',
        width: 65,
        height: 65,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.shopping_bag,
            size: 55,
            color: pink,
          );
        },
      );
    }

    if (logoUrl == null || logoUrl.trim().isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: localLogo(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        logoUrl,
        width: 65,
        height: 65,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return localLogo();
        },
      ),
    );
  }

  // --------------------------------------------------
  // MAIN RESPONSIVE LAYOUT
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isSmall = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F8FA),

          // MOBILE / TABLET DRAWER
          drawer: isWide
              ? null
              : Drawer(
                  child: _buildSidebar(inDrawer: true),
                ),

          // TOP APP BAR
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: !isWide,

            title: Text(
              menuItems[selectedIndex],
              style: TextStyle(
                fontSize: isSmall ? 17 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            actions: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFCE8EF),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: darkPink,
                ),
              ),

              if (!isSmall) ...[
                const SizedBox(width: 10),

                const Text(
                  'Administrator',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],

              const SizedBox(width: 20),
            ],
          ),

          // MAIN BODY
          body: Row(
            children: [
              // DESKTOP SIDEBAR
              if (isWide) _buildSidebar(),

              // PAGE CONTENT
              Expanded(
                child: _buildPage(),
              ),
            ],
          ),
        );
      },
    );
  }
}
