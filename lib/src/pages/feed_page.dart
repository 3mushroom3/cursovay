import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../domain/moderation/public_feed_policy.dart';
import '../models/proposal_status.dart';
import '../utils/date_format.dart';
import '../widgets/dgtu_background.dart';
import 'detail_page.dart';
import 'create_proposal_page.dart';
import 'statistics_page.dart';
import 'users_admin_page.dart';
import '../attachment_image.dart';
import '../repositories/categories_repository.dart';
import '../repositories/proposals_repository.dart';
import 'categories_admin_page.dart';
import 'reports_export_page.dart';

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
  bool myOnly = false;
  DateTime? dateFrom;
  DateTime? dateTo;

  Color _statusColor(String status) {
    switch (ProposalStatus.normalize(status)) {
      case ProposalStatus.submitted:
        return Colors.orange;
      case ProposalStatus.pending:
        return Colors.blue;
      case ProposalStatus.inProgress:
        return Colors.purple;
      case ProposalStatus.published:
        return Colors.teal;
      case ProposalStatus.completed:
      case ProposalStatus.closed:
        return Colors.green;
      case ProposalStatus.rejected:
        return Colors.red;
      case ProposalStatus.archived:
        return Colors.blueGrey;
      case ProposalStatus.transferred:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  bool _matchesFilters(Map<String, dynamic> data, String? currentUid) {
    final st = ProposalStatus.normalize(data['status'] as String?);
    if (statusFilter != 'all' && st != statusFilter) return false;
    if (categoryFilter != 'all' &&
        (data['categoryId'] as String?) != categoryFilter) return false;
    if (myOnly && (data['authorId'] as String?) != currentUid) return false;

    final created = (data['createdAt'] as Timestamp?)?.toDate();
    if (dateFrom != null && created != null && created.isBefore(dateFrom!)) {
      return false;
    }
    if (dateTo != null && created != null) {
      final endOfDay = dateTo!.add(const Duration(days: 1));
      if (created.isAfter(endOfDay)) return false;
    }

    final q = queryText.trim().toLowerCase();
    if (q.isEmpty) return true;
    final title = (data['title'] as String? ?? '').toLowerCase();
    final text = (data['text'] as String? ?? '').toLowerCase();
    return title.contains(q) || text.contains(q);
  }

  Future<void> _confirmAndDeleteProposal(
      BuildContext context, String proposalId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить предложение?'),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ProposalsRepository.deleteProposal(proposalId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Предложение удалено')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось удалить: $e')));
    }
  }

  Widget _proposalCard({
    required BuildContext context,
    required DocumentSnapshot doc,
    required AuthService auth,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    final normalized = ProposalStatus.normalize(status);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final votesFor = (data['votesForCount'] as int?) ?? 0;
    final votesAgainst = (data['votesAgainstCount'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailPage(id: doc.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data['title'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (auth.isAdmin)
                    IconButton(
                      tooltip: 'Удалить',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () =>
                          _confirmAndDeleteProposal(context, doc.id),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ProposalListImageLeading(attachments: data['attachments']),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ProposalStatus.label(normalized),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.thumb_up_outlined, size: 14,
                      color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('$votesFor',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 10),
                  Icon(Icons.thumb_down_outlined, size: 14,
                      color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('$votesAgainst',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  formatDate(createdAt),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.profileLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Предложения')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Не удалось загрузить профиль.\nПроверьте подключение к интернету.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  auth.loadProfile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final profileStatus = auth.profile?['status'] ?? '';

    if (profileStatus == 'unverified') {
      return Scaffold(
        appBar: AppBar(title: const Text('Предложения')),
        body: const Center(
          child: Text('Ожидайте проверки вашего профиля',
              style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
        ),
      );
    }

    if (profileStatus == 'disabled') {
      return Scaffold(
        appBar: AppBar(title: const Text('Предложения')),
        body: const Center(
          child: Text('Вам отказано в регистрации.\nВаш документ не прошел проверку.',
              style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
        ),
      );
    }

    final canPost = auth.canPostProposals;
    final allStream = FirebaseFirestore.instance
        .collection('proposals')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Предложения'),
        actions: [
          if (auth.isAdmin || auth.isModerator)
            IconButton(
              tooltip: 'Пользователи и заявки',
              icon: const Icon(Icons.supervisor_account),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UsersAdminPage())),
            ),
          if (auth.isAdmin || auth.isModerator)
            IconButton(
              tooltip: 'Отчёты',
              icon: const Icon(Icons.description_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsExportPage())),
            ),
          if (auth.isAdmin)
            IconButton(
              tooltip: 'Категории',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CategoriesAdminPage())),
            ),
          // Статистика — только для модераторов и администраторов
          if (auth.isAdmin || auth.isModerator)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Статистика',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StatisticsPage())),
            ),
          IconButton(
            tooltip: 'Сортировка',
            icon: Icon(sortBy == 'date' ? Icons.schedule : Icons.trending_up),
            onPressed: () =>
                setState(() => sortBy = sortBy == 'date' ? 'popularity' : 'date'),
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
                    decoration: const InputDecoration(labelText: 'Текст'),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text('Отмена')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, controller.text),
                        child: const Text('Искать')),
                  ],
                ),
              );
              if (result != null) setState(() => queryText = result);
            },
          ),
          IconButton(
            tooltip: 'Фильтры',
            icon: Badge(
              isLabelVisible: myOnly ||
                  statusFilter != 'all' ||
                  categoryFilter != 'all' ||
                  dateFrom != null ||
                  dateTo != null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () async {
              String nextStatus = statusFilter;
              String nextCategory = categoryFilter;
              bool nextMyOnly = myOnly;
              DateTime? nextFrom = dateFrom;
              DateTime? nextTo = dateTo;

              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Фильтры'),
                  content: StatefulBuilder(
                    builder: (ctx, setLocal) {
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Только мои предложения'),
                              value: nextMyOnly,
                              onChanged: (v) =>
                                  setLocal(() => nextMyOnly = v ?? false),
                            ),
                            const Divider(),
                            DropdownButtonFormField<String>(
                              value: nextStatus,
                              decoration:
                                  const InputDecoration(labelText: 'Статус'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('Все статусы')),
                                DropdownMenuItem(
                                    value: ProposalStatus.pending,
                                    child: Text('На рассмотрении')),
                                DropdownMenuItem(
                                    value: ProposalStatus.inProgress,
                                    child: Text('В работе')),
                                DropdownMenuItem(
                                    value: ProposalStatus.completed,
                                    child: Text('Завершено')),
                                DropdownMenuItem(
                                    value: ProposalStatus.rejected,
                                    child: Text('Отклонено')),
                                DropdownMenuItem(
                                    value: ProposalStatus.published,
                                    child: Text('Опубликовано')),
                              ],
                              onChanged: (v) =>
                                  setLocal(() => nextStatus = v ?? 'all'),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: CategoriesRepository.watchOrdered(),
                              builder: (context, snapshot) {
                                final docs = snapshot.data?.docs ?? const [];
                                final items = <DropdownMenuItem<String>>[
                                  const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Все категории')),
                                  ...docs.map(
                                    (d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(
                                          d.data()['name'] as String? ?? d.id),
                                    ),
                                  ),
                                ];
                                final value = items
                                        .any((e) => e.value == nextCategory)
                                    ? nextCategory
                                    : 'all';
                                return DropdownButtonFormField<String>(
                                  value: value,
                                  decoration: const InputDecoration(
                                      labelText: 'Категория'),
                                  items: items,
                                  onChanged: (v) => setLocal(
                                      () => nextCategory = v ?? 'all'),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Дата создания',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.calendar_today,
                                        size: 16),
                                    label: Text(nextFrom == null
                                        ? 'С...'
                                        : formatDate(nextFrom!)),
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: ctx,
                                        initialDate:
                                            nextFrom ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (d != null) {
                                        setLocal(() => nextFrom = d);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.calendar_today,
                                        size: 16),
                                    label: Text(nextTo == null
                                        ? 'По...'
                                        : formatDate(nextTo!)),
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: ctx,
                                        initialDate: nextTo ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (d != null) {
                                        setLocal(() => nextTo = d);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (nextFrom != null || nextTo != null)
                              TextButton(
                                onPressed: () => setLocal(() {
                                  nextFrom = null;
                                  nextTo = null;
                                }),
                                child: const Text('Сбросить даты'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена')),
                    TextButton(
                      onPressed: () {
                        nextStatus = 'all';
                        nextCategory = 'all';
                        nextMyOnly = false;
                        nextFrom = null;
                        nextTo = null;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Сбросить'),
                    ),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Применить')),
                  ],
                ),
              );

              if (result == true && mounted) {
                setState(() {
                  statusFilter = nextStatus;
                  categoryFilter = nextCategory;
                  myOnly = nextMyOnly;
                  dateFrom = nextFrom;
                  dateTo = nextTo;
                });
              }
            },
          ),
        ],
      ),
      body: DgtuBackground(
        child: StreamBuilder<QuerySnapshot>(
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
              return _matchesFilters(data, auth.user?.uid) &&
                  PublicFeedPolicy.isVisibleInFeed(
                    data: data,
                    currentUserId: auth.user?.uid,
                    isModerator: auth.isModerator || auth.isAdmin,
                  );
            }).toList();
            filtered.sort((a, b) {
              final ad = a.data() as Map<String, dynamic>;
              final bd = b.data() as Map<String, dynamic>;
              if (sortBy == 'popularity') {
                final av = (ad['votesForCount'] as int?) ?? 0;
                final bv = (bd['votesForCount'] as int?) ?? 0;
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: filtered
                  .map((doc) =>
                      _proposalCard(context: context, doc: doc, auth: auth))
                  .toList(),
            );
          },
        ),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateProposalPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Предложение'),
            )
          : null,
    );
  }
}
