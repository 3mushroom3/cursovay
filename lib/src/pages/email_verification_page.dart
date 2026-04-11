import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';

class EmailVerificationPage extends StatelessWidget {
  const EmailVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение email'),
        actions: [
          IconButton(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Мы отправили письмо для подтверждения адреса электронной почты. '
              'Подтвердите email и нажмите "Проверить".',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                try {
                  await auth.reloadUser();
                  if (!context.mounted) return;
                  final u = auth.user;
                  final msg = u == null
                      ? 'Аккаунт не найден (возможно, удалён в консоли). Войдите или зарегистрируйтесь снова.'
                      : auth.isEmailVerified
                          ? 'Email подтверждён.'
                          : 'Пока не видим подтверждения. Откройте ссылку из письма и нажмите «Проверить» снова.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message ?? e.code),
                    ),
                  );
                }
              },
              child: const Text('Проверить'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await auth.sendVerificationEmail();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Письмо отправлено повторно')),
                );
              },
              child: const Text('Отправить письмо снова'),
            ),
          ],
        ),
      ),
    );
  }
}
