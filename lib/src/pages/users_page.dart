import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/user_roles.dart';
import '../repositories/categories_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../services/notification_service.dart';
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

    final profileRepo = UserProfileRepository();

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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

          final data = snapshot.data!.data()!;
          final roleStatus = data['role'] ?? '';
          final roleText = UserRoles.labelRu(roleStatus as String?);
          final email = data['email'] ?? '';
          final fullName = (data['fullName'] as String?)?.trim() ?? '';
          final createdAt = data['createdAt'] as Timestamp?;
          final rawStatus = data['status'] ?? '';
          final statusText = statusLabel(rawStatus as String);
          final favoriteIds = (data['favoriteCategoryIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (fullName.isNotEmpty)
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (fullName.isNotEmpty) const SizedBox(height: 8),
              Text(
                email.toString(),
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
              const SizedBox(height: 24),
              Text(
                'Уведомления по категориям',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите категории: при появлении новых опубликованных предложений '
                'сервер может слать push подписчикам топика (нужна Cloud Function).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: CategoriesRepository.watchOrdered(),
                builder: (context, catSnap) {
                  if (!catSnap.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final docs = catSnap.data!.docs;
                  if (docs.isEmpty) {
                    return const Text('Категории ещё не созданы.');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: docs.map((d) {
                      final name = d.data()['name'] as String? ?? d.id;
                      final on = favoriteIds.contains(d.id);
                      return FilterChip(
                        label: Text(name),
                        selected: on,
                        onSelected: (v) async {
                          final prev = List<String>.from(favoriteIds);
                          final next = List<String>.from(favoriteIds);
                          if (v) {
                            if (!next.contains(d.id)) next.add(d.id);
                          } else {
                            next.remove(d.id);
                          }
                          await profileRepo.setFavoriteCategoryIds(
                            uid: user.uid,
                            categoryIds: next,
                          );
                          await NotificationService.applyFavoriteCategoryTopics(
                            previousIds: prev,
                            nextIds: next,
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              if (auth.isAdmin || auth.isModerator) ...[
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
          );
        },
      ),
    );
  }
}
