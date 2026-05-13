import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/user_roles.dart';
import '../repositories/categories_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../services/notification_service.dart';
import '../theme_notifier.dart';
import '../utils/date_format.dart';
import 'users_admin_page.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final themeNotifier = context.watch<ThemeNotifier>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Пользователь не найден')));
    }

    final profileRepo = UserProfileRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            tooltip: themeNotifier.isDark ? 'Светлая тема' : 'Тёмная тема',
            icon: Icon(
              themeNotifier.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: themeNotifier.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => auth.signOut(),
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

          final data = snapshot.data!.data()!;
          final roleRaw = data['role'] as String? ?? '';
          final roleText = UserRoles.labelRu(roleRaw);
          final email = data['email'] as String? ?? '';
          final fullName = (data['fullName'] as String?)?.trim() ?? '';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final rawStatus = data['status'] as String? ?? '';
          final favoriteIds = (data['favoriteCategoryIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];

          String statusLabel(String s) {
            switch (s) {
              case 'verified':
                return 'Подтверждённая учётная запись';
              case 'unverified':
                return 'На рассмотрении';
              case 'disabled':
                return 'В регистрации отказано';
              default:
                return 'Неизвестно';
            }
          }

          Color statusColor(String s) {
            switch (s) {
              case 'verified':
                return Colors.green;
              case 'disabled':
                return Colors.red;
              default:
                return Colors.orange;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Аватар с инициалами
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF1370B9),
                  child: Text(
                    fullName.isNotEmpty
                        ? fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join()
                        : (email.isNotEmpty ? email[0].toUpperCase() : '?'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (fullName.isNotEmpty)
                Center(
                  child: Text(
                    fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              Center(
                child: Text(email,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileRow(
                          icon: Icons.badge_outlined,
                          label: 'Роль',
                          value: roleText),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.circle,
                              size: 10,
                              color: statusColor(rawStatus)),
                          const SizedBox(width: 8),
                          Icon(Icons.verified_user_outlined,
                              size: 18,
                              color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusLabel(rawStatus),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: statusColor(rawStatus)),
                            ),
                          ),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 10),
                        _ProfileRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Дата регистрации',
                          value: formatDate(createdAt),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Уведомления по категориям',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Получайте уведомления о новых предложениях в выбранных категориях.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                  label: const Text('Пользователи и заявки'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const UsersAdminPage()),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
