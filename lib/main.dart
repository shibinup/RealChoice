import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_colors.dart';
import 'screens/login_page.dart';
import 'screens/pin_page.dart';
import 'package:realchoice/services/auth_service.dart';

/// App entry point.
/// Before the first frame we check whether the user is already logged in,
/// so we can decide which screen to open first.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase — if it fails (e.g. missing google-services.json),
  // we degrade gracefully by treating the user as logged-out.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    print("firebase ready");
    firebaseReady = true;
  } catch (err) {
    firebaseReady = false;

  }

  final bool loggedIn = firebaseReady && AuthService.isLoggedIn;

  runApp(RcSolutionsApp(startOnPin: loggedIn));//here pass constructor parameter is logged in true or false as loggedIn
}

class RcSolutionsApp extends StatelessWidget {
  /// true  -> user already logged in earlier -> open PIN page
  /// false -> fresh / logged-out user        -> open Login page
  final bool startOnPin;

  const RcSolutionsApp({super.key, required this.startOnPin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Choice Used Cars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: startOnPin ? const PinPage() : const LoginPage(),
    );
  }
}
