import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_colors.dart';
import '../services/admin_service.dart';

// ---------------------------------------------------------------------------
// Tab 3 – Manage Admin (only visible to main admin)
// ---------------------------------------------------------------------------

class ManageAdminTab extends StatefulWidget {
  const ManageAdminTab({super.key});

  @override
  State<ManageAdminTab> createState() => _ManageAdminTabState();
}

class _ManageAdminTabState extends State<ManageAdminTab> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _addAdmin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isAdding = true);
    try {
      final result = await AdminService.addAdmin(
        email: _emailController.text.trim(),
        pin: _pinController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _emailController.clear();
      _pinController.clear();
      _passwordController.clear();
      final msg = result == AddAdminResult.reactivated
          ? 'Admin reactivated with new PIN.'
          : 'Sub-admin added successfully.';
      _showSnack(msg, isError: false);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deactivateAdmin(String docId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Deactivate Admin',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Deactivate "$email"?\n\nThey will lose access immediately but can be reactivated later by adding them again.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminService.deactivateAdmin(docId);
      _showSnack('"$email" deactivated.', isError: false);
    } catch (e) {
      _showSnack('Failed to deactivate admin: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Decorative gold arcs
        Positioned(
          top: -60,
          left: -60,
          child: _ManageAdminArc(),
        ),
        Positioned(
          bottom: -60,
          right: -60,
          child: _ManageAdminArc(flip: true),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo row
                    Row(
                      children: [
                        CustomPaint(
                          size: const Size(60, 28),
                          painter: _CarSilhouettePainter(),
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
                    const SizedBox(height: 24),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Manage ',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: 'Admin',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'View and manage admin accounts',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Scrollable body ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Add Admin card ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card title
                              const Row(
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    color: AppColors.gold,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Add Admin',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                    color: AppColors.textPrimary),
                                decoration: _fieldDecoration(
                                  hint: 'Admin Email',
                                  icon: Icons.mail_outline_rounded,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // PIN field (always obscured – never displayed)
                              TextFormField(
                                controller: _pinController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 4,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  letterSpacing: 8,
                                  fontSize: 18,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: _fieldDecoration(
                                  hint: 'PIN',
                                  icon: Icons.shield_outlined,
                                ).copyWith(
                                  counterText: '',
                                  helperText:
                                      'Enter the PIN given during admin setup',
                                  helperStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'PIN is required';
                                  }
                                  if (v.length != 4) {
                                    return 'PIN must be exactly 4 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Password field (used to create Firebase Auth account)
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                    color: AppColors.textPrimary),
                                decoration: _fieldDecoration(
                                  hint: 'Email Password',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword),
                                  ),
                                ).copyWith(
                                  helperText:
                                      'Min. 6 characters needed',
                                  helperStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (v.trim().length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Add Admin button
                              GestureDetector(
                                onTap: _isAdding ? null : _addAdmin,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: _isAdding
                                        ? const LinearGradient(colors: [
                                            Color(0xFF7A6010),
                                            Color(0xFF9E8025),
                                          ])
                                        : const LinearGradient(colors: [
                                            AppColors.gold,
                                            AppColors.goldLight,
                                          ]),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.gold.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isAdding
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.black87,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.add,
                                                  color: Colors.black87,
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Add Admin',
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Admins List (real-time stream) ───────────────────
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: AdminService.streamAdmins(),
                        builder: (context, snapshot) {
                          // Header row (always rendered regardless of state)
                          final header = Row(
                            children: [
                              const Icon(
                                Icons.people_alt_outlined,
                                color: AppColors.gold,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Admins List',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if (snapshot.hasData)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Total: ${snapshot.data!.docs.length}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          );

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                header,
                                const SizedBox(height: 24),
                                const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.gold),
                                ),
                              ],
                            );
                          }

                          if (snapshot.hasError) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                header,
                                const SizedBox(height: 20),
                                Text(
                                  'Error loading admins: ${snapshot.error}',
                                  style: const TextStyle(
                                      color: Colors.redAccent),
                                ),
                              ],
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              header,
                              const SizedBox(height: 14),
                              if (docs.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: AppColors.border),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'No admins found.',
                                      style: TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                  ),
                                )
                              else
                                ...docs.map((doc) {
                                  final data = doc.data();
                                  final email =
                                      data['email'] as String? ?? '—';
                                  final isMain =
                                      data['role'] == 'mainAdmin';
                                  final isActive =
                                      data['active'] as bool? ?? false;
                                  return AdminListTile(
                                    email: email,
                                    isMainAdmin: isMain,
                                    isActive: isActive,
                                    onDeactivate: isMain
                                        ? null // Prevent deactivating the main admin
                                        : () =>
                                            _deactivateAdmin(doc.id, email),
                                  );
                                }),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Admin list tile – shows email only (PIN is never displayed)
// ---------------------------------------------------------------------------

class AdminListTile extends StatelessWidget {
  final String email;
  final bool isMainAdmin;
  final bool isActive;
  final VoidCallback? onDeactivate;

  const AdminListTile({
    super.key,
    required this.email,
    required this.isMainAdmin,
    required this.isActive,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMainAdmin
              ? AppColors.gold.withValues(alpha: 0.4)
              : isActive
                  ? AppColors.border
                  : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Email icon – dimmed when inactive
          Icon(
            Icons.mail_outline_rounded,
            color: isActive
                ? AppColors.textSecondary
                : AppColors.textSecondary.withValues(alpha: 0.5),
            size: 20,
          ),
          const SizedBox(width: 12),

          // Email + role/status badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isActive ? null : TextDecoration.lineThrough,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Main Admin badge
                    if (isMainAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Main Admin',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Inactive badge
                    if (!isActive) ...[
                      if (isMainAdmin) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Deactivate button – hidden for main admin and already-inactive rows
          if (onDeactivate != null && isActive)
            GestureDetector(
              onTap: onDeactivate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_outlined,
                        color: Colors.redAccent, size: 16),
                    SizedBox(width: 5),
                    Text(
                      'Deactivate',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private painters (local copies so this file is self-contained)
// ---------------------------------------------------------------------------

class _ManageAdminArc extends StatelessWidget {
  final bool flip;
  const _ManageAdminArc({this.flip = false});

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

class _CarSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(4, size.height * 0.7);
    path.lineTo(10, size.height * 0.3);
    path.lineTo(20, size.height * 0.1);
    path.lineTo(40, size.height * 0.1);
    path.lineTo(52, size.height * 0.3);
    path.lineTo(56, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);

    // Wheels
    canvas.drawCircle(Offset(14, size.height * 0.82), 5, paint);
    canvas.drawCircle(Offset(46, size.height * 0.82), 5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
