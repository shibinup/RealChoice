import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../services/pin_service.dart';
import '../widgets/rc_logo.dart';
import 'dashboard_screen.dart';
import 'login_page.dart';

class PinPage extends StatefulWidget {
  const PinPage({super.key});

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage>
    with SingleTickerProviderStateMixin {
  final List<String> _digits = [];

  // Shake animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Numpad actions
  // ---------------------------------------------------------------------------

  void _onDigitPressed(String digit) {
    if (_digits.length >= 4) return;
    setState(() => _digits.add(digit));

    if (_digits.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _verifyPin() async {
    // Capture the joined PIN before any async work.
    final enteredPin = _digits.join();

    // Trigger a rebuild so the filled dots stay visible during the async call.
    setState(() {});

    try {
      final success = await PinService.verifyPin(enteredPin);
      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        await _shakeController.forward(from: 0);
        if (!mounted) return;
        setState(() => _digits.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Incorrect PIN'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() => _digits.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() => _digits.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Check your connection.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _goToLogin() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              // Logo
              const RcLogo(),
              const SizedBox(height: 40),

              // Title
              const Text(
                'Enter Shop PIN',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your 4-digit PIN to access your shop',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 36),

              // PIN dot indicators with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _shakeAnimation.value *
                          ((_shakeController.value * 10).toInt().isEven
                              ? 1
                              : -1),
                      0,
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _digits.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: filled
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: filled ? AppColors.gold : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: filled ? 18 : 10,
                          height: filled ? 18 : 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? AppColors.gold
                                : AppColors.border,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 48),

              // Custom numpad
              Expanded(
                child: _NumPad(
                  onDigit: _onDigitPressed,
                  onBackspace: _onBackspace,
                ),
              ),

              // Forgot PIN
              TextButton(
                onPressed: _goToLogin,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold),
                child: const Text('Forgot shop PIN?'),
              ),
              const SizedBox(height: 4),

              // Back to login
              TextButton(
                onPressed: _goToLogin,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary),
                child: const Text('← Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Numpad widget
// ---------------------------------------------------------------------------

class _NumPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    // Layout: 1-9 in rows of 3, then [blank, 0, backspace]
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((label) {
            if (label.isEmpty) {
              // Blank cell — same size but invisible
              return const SizedBox(width: 76, height: 64);
            }
            return _NumPadKey(
              label: label,
              onTap: label == '⌫' ? onBackspace : () => onDigit(label),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _NumPadKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumPadKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isBackspace = label == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 76,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined,
                  color: AppColors.textPrimary, size: 22)
              : Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
