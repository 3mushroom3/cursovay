import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/categories_repository.dart';

class CategoriesAdminPage extends StatefulWidget {
  const CategoriesAdminPage({super.key});

  @override
  State<CategoriesAdminPage> createState() => _CategoriesAdminPageState();
}

class _CategoriesAdminPageState extends State<CategoriesAdminPage> {
  final _controller = TextEditingController();
  bool _staffOnly = false;
  bool _seeding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                        const InputDecoration(labelText: 'Новая категория'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    final name = _controller.text.trim();
                    if (name.isEmpty) return;
                    await CategoriesRepository.createCategory(
                      name: name,
                      staffOnly: _staffOnly,
                    );
                    _controller.clear();
                    setState(() => _staffOnly = false);
                  },
                  child: const Text('Добавить'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Только для преподавателей'),
              subtitle: const Text(
                'Студенты не увидят эту категорию при создании предложения',
              ),
              value: _staffOnly,
              onChanged: (v) => setState(() => _staffOnly = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: CategoriesRepository.watchOrdered(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Категорий нет.\nМожно добавить вручную или создать набор по умолчанию.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _seeding
                                  ? null
                                  : () async {
                                      setState(() => _seeding = true);
                                      try {
                                        const general = [
                                          'Учебный процесс',
                                          'Общежитие',
                                          'Столовая',
                                          'Инфраструктура',
                                          'Мероприятия',
                                        ];
                                        const staffCategories = [
                                          'Методическая работа',
                                          'Научная деятельность',
                                          'Кафедральные вопросы',
                                        ];
                                        for (final name in general) {
                                          await CategoriesRepository
                                              .createCategory(name: name);
                                        }
                                        for (final name in staffCategories) {
                                          await CategoriesRepository
                                              .createCategory(
                                            name: name,
                                            staffOnly: true,
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _seeding = false);
                                        }
                                      }
                                    },
                              child: Text(
                                _seeding
                                    ? 'Создаю...'
                                    : 'Создать категории по умолчанию',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView(
                    children: docs.map((d) {
                      final name = d.data()['name'] as String? ?? d.id;
                      final isStaffOnly =
                          d.data()['staffOnly'] as bool? ?? false;
                      return ListTile(
                        title: Text(name),
                        subtitle: isStaffOnly
                            ? const Text(
                                'Только преподаватели',
                                style: TextStyle(color: Color(0xFF1370B9)),
                              )
                            : null,
                        leading: Icon(
                          isStaffOnly
                              ? Icons.school_outlined
                              : Icons.category_outlined,
                          color: isStaffOnly
                              ? const Color(0xFF1370B9)
                              : Colors.grey,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isStaffOnly ? Icons.lock : Icons.lock_open,
                                size: 20,
                              ),
                              tooltip: isStaffOnly
                                  ? 'Открыть для всех'
                                  : 'Только преподаватели',
                              onPressed: () async {
                                await CategoriesRepository.updateCategory(
                                  id: d.id,
                                  name: name,
                                  staffOnly: !isStaffOnly,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Удалить категорию?'),
                                    content: Text('«$name»'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Отмена'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await CategoriesRepository.deleteCategory(
                                      d.id);
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () async {
                          final c = TextEditingController(text: name);
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Переименовать'),
                              content: TextField(
                                controller: c,
                                decoration: const InputDecoration(
                                    labelText: 'Название'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, null),
                                  child: const Text('Отмена'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, c.text),
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            ),
                          );
                          final nn = newName?.trim();
                          if (nn != null && nn.isNotEmpty && nn != name) {
                            await CategoriesRepository.updateCategory(
                              id: d.id,
                              name: nn,
                            );
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
