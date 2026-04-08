import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/proposal_status.dart';
import 'detail_page.dart';
import 'create_proposal_page.dart';
import 'statistics_page.dart';
import 'users_admin_page.dart';
import '../repositories/categories_repository.dart';
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

  String _statusLabel(String status) {
    final normalized = ProposalStatus.normalize(status);
    return ProposalStatus.label(normalized);
  }

  List<QueryDocumentSnapshot> _mergeDocs(
    List<QueryDocumentSnapshot> a,
    List<QueryDocumentSnapshot> b,
  ) {
    final map = <String, QueryDocumentSnapshot>{};
    for (final d in a) {
      map[d.id] = d;
    }
    for (final d in b) {
      map[d.id] = d;
    }
    final list = map.values.toList();
    list.sort((x, y) {
      final xd = (x.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final yd = (y.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final xt = xd?.millisecondsSinceEpoch ?? 0;
      final yt = yd?.millisecondsSinceEpoch ?? 0;
      return yt.compareTo(xt);
    });
    return list;
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final st = ProposalStatus.normalize(data['status'] as String?);
    if (statusFilter != 'all') {
      if (statusFilter == ProposalStatus.inWork) {
        final raw = data['status'] as String?;
        if (!(raw == ProposalStatus.inWork || raw == ProposalStatus.inWorkLegacy)) {
          return false;
        }
      } else if (st != statusFilter) {
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

    final uid = auth.user!.uid;
    final isStaff = auth.isAdmin || auth.isModerator;
    final allStream = FirebaseFirestore.instance
        .collection('proposals')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final myStream = FirebaseFirestore.instance
        .collection('proposals')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
    final publicStream = FirebaseFirestore.instance
        .collection('proposals')
        .where('visibility', isEqualTo: 'public')
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
          if (auth.isModerator || auth.isAdmin)
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
                                  value: ProposalStatus.draft,
                                  child: Text('Новые'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.review,
                                  child: Text('На рассмотрении'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.needsInfo,
                                  child: Text('Нужно уточнение'),
                                ),
                                DropdownMenuItem(
                                  value: ProposalStatus.inWork,
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
      body: isStaff
          ? StreamBuilder<QuerySnapshot>(
              stream: allStream,
              builder: (context, allSnap) {
                if (allSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allDocs = allSnap.data?.docs ?? const [];
                final filtered = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _matchesFilters(data);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Нет предложений'));
                }
                return ListView(
                  children: filtered.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';
                    return ListTile(
                      title: Text(data['title'] ?? ''),
                      subtitle: Text(_statusLabel(status)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailPage(id: doc.id),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            )
          : StreamBuilder<QuerySnapshot>(
              stream: myStream,
              builder: (context, mySnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: publicStream,
                  builder: (context, pubSnap) {
                    final waiting =
                        mySnap.connectionState == ConnectionState.waiting ||
                            pubSnap.connectionState == ConnectionState.waiting;
                    if (waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final myDocs = mySnap.data?.docs ?? const [];
                    final pubDocs = pubSnap.data?.docs ?? const [];
                    final merged = _mergeDocs(myDocs, pubDocs);
                    final filtered = merged.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return _matchesFilters(data);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('Нет предложений'));
                    }
                    return ListView(
                      children: filtered.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? '';
                        return ListTile(
                          title: Text(data['title'] ?? ''),
                          subtitle: Text(_statusLabel(status)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailPage(id: doc.id),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
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