import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'signup_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      //appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SvgPicture.asset(
              'assets/logo.svg',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.loading
                  ? null
                  : () async {
                      final email = _email.text.trim();
                      final password = _password.text.trim();

                      if (email.isEmpty || password.isEmpty) {
                        _showError(context, 'Заполните все поля');
                        return;
                      }

                      try {
                        await auth.signIn(email, password);
                      } catch (e) {
                        _showError(context, e.toString());
                      }
                    },
              child: auth.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Войти'),
            ),
            TextButton(
              onPressed: () async {
                final email = _email.text.trim();
                if (email.isEmpty) {
                  _showError(context, 'Введите email');
                  return;
                }
                try {
                  await auth.resetPassword(email);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Письмо для сброса отправлено')),
                  );
                } catch (e) {
                  _showError(context, 'Ошибка сброса пароля');
                }
              },
              child: const Text('Забыли пароль?'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                );
              },
              child: const Text('Регистрация'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}