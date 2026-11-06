import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_colors.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'add_car_screen.dart';
import 'login_page.dart';
import 'manage_admin_tab.dart';

// ---------------------------------------------------------------------------
// Dashboard Shell – holds bottom nav + tab bodies
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  /// Whether the signed-in user has `role == "main admin"` in Firestore.
  bool _isMainAdmin = false;

  /// Whether the admin-role check has finished loading.
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  /// Check Firestore `admins` collection for the current user's role.
  Future<void> _loadRole() async {
    final mainAdmin = await AdminService.isMainAdmin();
    if (!mounted) return;
    setState(() {
      _isMainAdmin = mainAdmin;
      _roleLoaded = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Navigation items (Manage Admin shown only to main admin)
  // ---------------------------------------------------------------------------

  List<_NavItem> get _navItems {
    final items = <_NavItem>[
      _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.directions_car_outlined, label: 'Add Car'),
      if (_isMainAdmin)
        _NavItem(icon: Icons.admin_panel_settings_outlined, label: 'Manage Admin'),
      _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];
    return items;
  }

  /// The tab body to display at a given bottom-nav index.
  Widget _bodyForIndex(int index) {
    // Build logical tab list matching _navItems order.
    final bodies = <Widget>[
      _VehicleDashboardTab(isMainAdmin: _isMainAdmin),
      const _AddCarTab(),
      if (_isMainAdmin) const ManageAdminTab(),
      const _ProfileTab(),
    ];
    final safeIndex = index.clamp(0, bodies.length - 1);
    return bodies[safeIndex];
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while we wait for the role check.
    if (!_roleLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _bodyForIndex(_selectedIndex),
      bottomNavigationBar: _RcBottomNav(
        items: _navItems,
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Navigation Bar
// ---------------------------------------------------------------------------

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _RcBottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _RcBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E35),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: items
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon, size: 24),
                  activeIcon: Icon(item.icon, size: 24, color: AppColors.gold),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 – Vehicle Dashboard
// ---------------------------------------------------------------------------

class _VehicleDashboardTab extends StatefulWidget {
  final bool isMainAdmin;
  const _VehicleDashboardTab({required this.isMainAdmin});

  @override
  State<_VehicleDashboardTab> createState() => _VehicleDashboardTabState();
}

class _VehicleDashboardTabState extends State<_VehicleDashboardTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns a greeting depending on the current hour.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Display name: "Admin" for main admin, else the email local-part.
  String get _displayName {
    if (widget.isMainAdmin) return 'Admin';
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Decorative gold arcs matching the app's design language.
        Positioned(
          top: -60,
          left: -60,
          child: _DecorativeArc(),
        ),
        Positioned(
          bottom: -60,
          right: -60,
          child: _DecorativeArc(flip: true),
        ),

        SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo row
                      Row(
                        children: [
                          // RC logo image (circular, gold border)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.gold, width: 1.8),
                              color: AppColors.surface,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/rc_logo.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Real Choice Used Cars',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Drive Better. Choose Smart.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Greeting
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$_greeting, ',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: _displayName,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Vehicle Dashboard',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage your fleet at a glance',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Search bar
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search,
                                color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 14),
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v.trim()),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search by car number (e.g. KL 10 AB 1234)',
                                  hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            // Filter icon button
                            Container(
                              margin: const EdgeInsets.all(6),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(Icons.tune_rounded,
                                  color: AppColors.textSecondary, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section header
                      Row(
                        children: [
                          const Text(
                            'Your Vehicles',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              // TODO: navigate to full vehicles list
                            },
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.gold),
                            icon: const Text(
                              'View all',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            label: const Icon(Icons.arrow_forward, size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Vehicle list (from Firestore later; static demo for now) ─
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: _VehicleListSliver(searchQuery: _searchQuery),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle list sliver – static demo data (replace with Firestore stream later)
// ---------------------------------------------------------------------------

class _VehicleListSliver extends StatelessWidget {
  final String searchQuery;

  const _VehicleListSliver({required this.searchQuery});

  static const List<Map<String, String>> _vehicles = [
    {
      'make': 'Hyundai Creta',
      'plate': 'KL 10 AB 1234',
    },
    {
      'make': 'Toyota Innova Crysta',
      'plate': 'KL 07 CD 5678',
    },
    {
      'make': 'Maruti Suzuki Baleno',
      'plate': 'KL 11 EF 9012',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = searchQuery.isEmpty
        ? _vehicles
        : _vehicles
            .where((v) =>
                v['plate']!
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) ||
                v['make']!.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Center(
            child: Text(
              'No vehicles found for "$searchQuery"',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _VehicleCard(vehicle: filtered[index]),
        ),
        childCount: filtered.length,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual vehicle card
// ---------------------------------------------------------------------------

class _VehicleCard extends StatelessWidget {
  final Map<String, String> vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Car icon placeholder (use actual images from assets later)
          Container(
            width: 72,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car,
              color: AppColors.gold,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle['make'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // Plate number pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        vehicle['plate'] ?? '',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chevron
          const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 22),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 – Add Car
// ---------------------------------------------------------------------------

class _AddCarTab extends StatelessWidget {
  const _AddCarTab();

  @override
  Widget build(BuildContext context) {
    return const AddCarScreen();
  }
}

// ---------------------------------------------------------------------------
// Tab 4 – Profile
// ---------------------------------------------------------------------------

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '—';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2.5),
                color: AppColors.surface,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.gold,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              email,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Real Choice Used Cars',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            // Sign out button
            GestureDetector(
              onTap: () => _logout(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 1.5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic placeholder tab
// ---------------------------------------------------------------------------

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                  color: AppColors.surface,
                ),
                child: Icon(icon, color: AppColors.gold, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative gold arc (reused from LoginPage design language)
// ---------------------------------------------------------------------------

class _DecorativeArc extends StatelessWidget {
  final bool flip;
  const _DecorativeArc({this.flip = false});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      scaleY: flip ? -1 : 1,
      child: CustomPaint(
        size: const Size(160, 160),
        painter: _ArcPainter(),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final offset = i * 22.0;
      canvas.drawArc(
        Rect.fromLTWH(offset, offset, size.width * 1.2, size.height * 1.2),
        0,
        3.14 / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



