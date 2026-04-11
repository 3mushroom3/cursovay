import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/proposal_status.dart';
import 'detail_page.dart';
import 'create_proposal_page.dart';
import 'statistics_page.dart';
import 'users_admin_page.dart';
import '../attachment_image.dart';
import '../repositories/categories_repository.dart';
import '../repositories/proposals_repository.dart';
import 'categories_admin_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String statusFilter = 'all';
  String categoryFilter = 'all';
  String queryText = '';
  String sortBy = 'date';

  String _statusLabel(String status) {
    final normalized = ProposalStatus.normalize(status);
    return ProposalStatus.label(normalized);
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final st = ProposalStatus.normalize(data['status'] as String?);
    if (statusFilter != 'all') {
      if (st != statusFilter) {
        return false;
      }
    }

    if (categoryFilter != 'all') {
      if ((data['categoryId'] as String?) != categoryFilter) return false;
    }

    final q = queryText.trim().toLowerCase();
    if (q.isEmpty) return true;
    final title = (data['title'] as String? ?? '').toLowerCase();
    final text = (data['text'] as String? ?? '').toLowerCase();
    return title.contains(q) || text.contains(q);
  }

  Future<void> _confirmAndDeleteProposal(
    BuildContext context,
    String proposalId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить предложение?'),
        content: const Text('Действие нельзя отменить.'),
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
    if (ok != true || !context.mounted) return;
    try {
      await ProposalsRepository.deleteProposal(proposalId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Предложение удалено')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: $e')),
      );
    }
  }

  Widget _proposalListTile({
    required BuildContext context,
    required DocumentSnapshot doc,
    required AuthService auth,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    return ListTile(
      title: Text(data['title'] as String? ?? ''),
      subtitle: Text(_statusLabel(status)),
      leading: ProposalListImageLeading(attachments: data['attachments']),
      trailing: auth.isAdmin
          ? IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmAndDeleteProposal(context, doc.id),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(id: doc.id),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.profileLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileStatus = auth.profile?['status'] ?? '';

    if (profileStatus == 'unverified') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Предложения'),
        ),
        body: const Center(
          child: Text(
            'Ожидайте проверки вашего профиля',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (profileStatus == 'disabled') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Предложения'),
        ),
        body: const Center(
          child: Text(
            'Вам отказано в регистрации.\n Ваш документ не прошел проверку.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isTeacherOrAdmin = auth.isAdmin || auth.isTeacher;
    final allStream = FirebaseFirestore.instance
        .collection('proposals')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Предложения'),
        actions: [
          // У правого края; при overflow узкого AppBar не теряется.
          if (auth.isAdmin)
            IconButton(
              tooltip: 'Пользователи и заявки',
              icon: const Icon(Icons.supervisor_account),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersAdminPage()),
                );
              },
            ),
          if (auth.isTeacher || auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.category_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesAdminPage()),
                );
              },
            ),
          IconButton(
            tooltip: 'Сортировка',
            icon: const Icon(Icons.sort),
            onPressed: () => setState(() {
              sortBy = sortBy == 'date' ? 'popularity' : 'date';
            }),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final controller = TextEditingController(text: queryText);
              final result = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Поиск'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Текст',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Искать'),
                    ),
                  ],
                ),
              );
              if (result != null) setState(() => queryText = result);
            },
          ),
          IconButton(
            tooltip: 'Фильтры',
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              String nextStatus = statusFilter;
              String nextCategory = categoryFilter;

              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Фильтры'),
                    content: StatefulBuilder(
                      builder: (ctx, setLocal) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String>(
                              value: nextStatus,
                              decoration:
                                  const InputDecoration(labelText: 'Статус'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Все'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.pending,
                                  child: Text('На рассмотрении'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.inProgress,
                                  child: Text('В работе'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.completed,
                                  child: Text('Завершено'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.rejected,
                                  child: Text('Отклонено'),
                                ),
                              ],
                              onChanged: (v) => setLocal(
                                () => nextStatus = v ?? 'all',
                              ),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: CategoriesRepository.watchOrdered(),
                              builder: (context, snapshot) {
                                final docs = snapshot.data?.docs ?? const [];
                                final items = <DropdownMenuItem<String>>[
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Все категории'),
                                  ),
                                  ...docs.map(
                                    (d) => DropdownMenuItem(
                                      value: d.id,
                                      child:
                                          Text(d.data()['name'] as String? ?? d.id),
                                    ),
                                  ),
                                ];
                                final value = items.any((e) => e.value == nextCategory)
                                    ? nextCategory
                                    : 'all';
                                return DropdownButtonFormField<String>(
                                  value: value,
                                  decoration: const InputDecoration(
                                    labelText: 'Категория',
                                  ),
                                  items: items,
                                  onChanged: (v) => setLocal(
                                    () => nextCategory = v ?? 'all',
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Применить'),
                      ),
                    ],
                  );
                },
              );

              if (result == true && mounted) {
                setState(() {
                  statusFilter = nextStatus;
                  categoryFilter = nextCategory;
                });
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
              stream: allStream,
              builder: (context, allSnap) {
                if (allSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (allSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Не удалось загрузить ленту: ${allSnap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final allDocs = allSnap.data?.docs ?? const [];
                final filtered = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _matchesFilters(data);
                }).toList();
                filtered.sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;
                  if (sortBy == 'popularity') {
                    final av = (ad['votesCount'] as int?) ?? 0;
                    final bv = (bd['votesCount'] as int?) ?? 0;
                    return bv.compareTo(av);
                  }
                  final ac = ad['createdAt'] as Timestamp?;
                  final bc = bd['createdAt'] as Timestamp?;
                  return (bc?.millisecondsSinceEpoch ?? 0)
                      .compareTo(ac?.millisecondsSinceEpoch ?? 0);
                });
                if (filtered.isEmpty) {
                  return const Center(child: Text('Нет предложений'));
                }
                return ListView(
                  children: filtered
                      .map(
                        (doc) => _proposalListTile(
                          context: context,
                          doc: doc,
                          auth: auth,
                        ),
                      )
                      .toList(),
                );
              },
            ),
      floatingActionButton: isTeacherOrAdmin
          ? null
          : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateProposalPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
