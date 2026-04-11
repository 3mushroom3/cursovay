import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/user_roles.dart';
import 'users_admin_page.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не найден')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Профиль не найден'));
          }
          String statusLabel(String status) {
            switch (status) {
              case 'verified':
                return 'Подтверждённая учетная запись';
              case 'unverified':
                return 'На рассмотрении';
              case 'disabled':
                return 'В регистрации отказано';
              default:
                return 'Неизвестно';
            }
          }
          String roleLabel(String role) {
            final normalized = UserRoles.normalize(role);
            switch (normalized) {
              case UserRoles.student:
                return 'Студент';
              case UserRoles.teacher:
                return 'Преподаватель';
              case UserRoles.admin:
                return 'Администратор';
              default:
                return 'Неизвестно';
            }
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final roleStatus = data['role'] ?? '';
          final roleText = roleLabel(roleStatus);
          final email = data['email'] ?? '';
          final fullName = (data['fullName'] as String?)?.trim() ?? '';
          final createdAt = data['createdAt'] as Timestamp?;
          final rawStatus = data['status'] ?? '';
          final statusText = statusLabel(rawStatus);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fullName.isNotEmpty)
                  Text(
                    fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (fullName.isNotEmpty) const SizedBox(height: 8),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text('Роль: $roleText'),
                const SizedBox(height: 12),
                Text('Статус: $statusText'),
                const SizedBox(height: 12),
                if (createdAt != null)
                  Text(
                    'Дата регистрации: ${createdAt.toDate()}',
                  ),
                if (auth.isAdmin) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.supervisor_account),
                    label: const Text('Пользователи и заявки на регистрацию'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const UsersAdminPage(),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}