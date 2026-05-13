import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'services/notification_service.dart';
import 'pages/auth_page.dart';
import 'pages/email_verification_page.dart';
import 'pages/home_page.dart';
import 'pages/landing_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _landingSeen = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return StreamBuilder(
      stream: auth.authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          if (!_landingSeen) {
            return LandingPage(
              onContinue: () => setState(() => _landingSeen = true),
            );
          }
          return const AuthPage();
        }

        if (auth.profile == null && !auth.profileLoaded) {
          auth.loadProfile();
        }

        if (!auth.isEmailVerified) {
          return const EmailVerificationPage();
        }

        // Best-effort token save (FCM). For Emulator-only usage, this is safe.
        NotificationService.initAndSaveToken();

        return const HomePage();
      },
    );
  }
}