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
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'Новая категория'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    final name = _controller.text.trim();
                    if (name.isEmpty) return;
                    await CategoriesRepository.createCategory(name: name);
                    _controller.clear();
                  },
                  child: const Text('Добавить'),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                              'Категорий нет.\nМожно добавить вручную или создать набор по умолчанию из ТЗ.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _seeding
                                  ? null
                                  : () async {
                                      setState(() => _seeding = true);
                                      try {
                                        const defaults = [
                                          'Учебный процесс',
                                          'Общежитие',
                                          'Столовая',
                                          'Инфраструктура',
                                          'Мероприятия',
                                        ];
                                        for (final name in defaults) {
                                          await CategoriesRepository
                                              .createCategory(name: name);
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
                      return ListTile(
                        title: Text(name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Удалить категорию?'),
                                content: Text('«$name»'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Отмена'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Удалить'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await CategoriesRepository.deleteCategory(d.id);
                            }
                          },
                        ),
                        onTap: () async {
                          final c = TextEditingController(text: name);
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Переименовать'),
                              content: TextField(
                                controller: c,
                                decoration:
                                    const InputDecoration(labelText: 'Название'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, null),
                                  child: const Text('Отмена'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, c.text),
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

