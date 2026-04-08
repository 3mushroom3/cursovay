import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'services/notification_service.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
          return const AuthPage();
        }

        if (auth.profile == null) {
          auth.loadProfile();
        }

        // Best-effort token save (FCM). For Emulator-only usage, this is safe.
        NotificationService.initAndSaveToken();

        return const HomePage();
      },
    );
  }
}