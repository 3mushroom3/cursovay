import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/user_roles.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _middleName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  String _role = UserRoles.student;
  PlatformFile? _document;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _middleName.dispose();
    _email.dispose();
    _password.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() => _document = r.files.first);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: auth.loading ? null : _pickDocument,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: _document == null
                      ? const Text(
                          'Фото JPG/PNG для подтверждения личности\n'
                          '(не больше 500 КБ — хранится в Firestore, без Cloud Storage)',
                          textAlign: TextAlign.center,
                        )
                      : _IdentityPreview(file: _document!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Фамилия'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _middleName,
              decoration: const InputDecoration(labelText: 'Отчество (необязательно)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Роль'),
              items: const [
                DropdownMenuItem(
                  value: UserRoles.student,
                  child: Text('Студент'),
                ),
                DropdownMenuItem(
                  value: UserRoles.teacher,
                  child: Text('Преподаватель'),
                ),
              ],
              onChanged: auth.loading ? null : (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repeatPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Повторите пароль'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.loading
                  ? null
                  : () async {
                      final email = _email.text.trim();
                      final password = _password.text.trim();
                      final repeatPassword = _repeatPassword.text.trim();
                      final firstName = _firstName.text.trim();
                      final lastName = _lastName.text.trim();
                      final middleName = _middleName.text.trim();

                      if (email.isEmpty ||
                          password.isEmpty ||
                          firstName.isEmpty ||
                          lastName.isEmpty) {
                        _showError(context, 'Заполните все поля');
                        return;
                      }
                      final passValidation = AuthService.validatePassword(password);
                      if (passValidation != null) {
                        _showError(context, passValidation);
                        return;
                      }
                      if (password != repeatPassword) {
                        _showError(context, 'Пароли не совпадают');
                        return;
                      }

                      if (_document == null ||
                          ((_document!.path == null || _document!.path!.isEmpty) &&
                              (_document!.bytes == null ||
                                  _document!.bytes!.isEmpty))) {
                        _showError(
                          context,
                          'Добавьте фото JPG или PNG для подтверждения личности',
                        );
                        return;
                      }

                      try {
                        await auth.signUp(
                          email: email,
                          password: password,
                          firstName: firstName,
                          lastName: lastName,
                          middleName: middleName.isEmpty ? null : middleName,
                          role: _role,
                          document: _document!,
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (!mounted) return;
                        if (e is FormatException) {
                          _showError(context, e.message);
                          return;
                        }
                        final msg = e is FirebaseException
                            ? _mapSignUpFirebaseError(e)
                            : 'Ошибка регистрации';
                        _showError(
                          context,
                          msg.length > 320 ? '${msg.substring(0, 320)}…' : msg,
                        );
                      }
                    },
              child: auth.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Создать аккаунт'),
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

  String _mapSignUpFirebaseError(FirebaseException e) {
    final c = e.code;
    final m = e.message ?? '';
    if (c.contains('permission') ||
        m.contains('Firestore API has not been used') ||
        m.contains('firestore.googleapis.com')) {
      return 'Включите Firestore: Firebase → Firestore → создайте БД; в Google Cloud '
          '→ APIs → включите «Cloud Firestore API» для проекта dgtu-ff8cf.';
    }
    return m.isNotEmpty ? m : 'Ошибка регистрации ($c)';
  }
}

class _IdentityPreview extends StatelessWidget {
  const _IdentityPreview({required this.file});

  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_context, _error, _stackTrace) => _fallbackLabel(),
        ),
      );
    }
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      );
    }
    return _fallbackLabel();
  }

  Widget _fallbackLabel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        file.name,
        textAlign: TextAlign.center,
      ),
    );
  }
}
