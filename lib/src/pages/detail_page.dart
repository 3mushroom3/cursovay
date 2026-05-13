import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../attachment_image.dart';
import '../data/moderation/client_moderation_pipeline.dart';
import '../data/moderation/firestore_duplicate_heuristic.dart';
import '../domain/core/failure.dart';
import '../domain/entities/handover_department.dart';
import '../domain/moderation/automated_moderation_result.dart';
import '../models/proposal_status.dart';
import '../repositories/proposals_repository.dart';
import '../utils/date_format.dart';
import 'create_proposal_page.dart';

class DetailPage extends StatefulWidget {
  final String id;
  const DetailPage({super.key, required this.id});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _commentController = TextEditingController();
  final _newCommentController = TextEditingController();
  String? _status;
  String? _lastServerStatus;
  AutomatedModerationResult? _autoResult;
  bool _autoBusy = false;
  String _handoverDepartmentId = HandoverDepartment.defaults.first.id;
  DateTime? _votingDeadline;
  bool _savingDeadline = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canModerate = auth.isModerator || auth.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Детали предложения')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('proposals')
            .doc(widget.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Предложение не найдено'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final comment = data['comment'] as String?;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
          final storedDeadline =
              (data['votingDeadline'] as Timestamp?)?.toDate();

          final normalizedStatus = ProposalStatus.normalize(status);
          if (_lastServerStatus != normalizedStatus) {
            final hasUnsaved =
                _status != null && _status != _lastServerStatus;
            _lastServerStatus = normalizedStatus;
            if (!hasUnsaved) _status = normalizedStatus;
          }
          if (_commentController.text.isEmpty && comment != null) {
            _commentController.text = comment;
          }
          if (_votingDeadline == null && storedDeadline != null) {
            _votingDeadline = storedDeadline;
          }

          final authorId = data['authorId'] as String?;
          final isAuthor = authorId != null && authorId == auth.user?.uid;
          final canAuthorEdit = isAuthor &&
              (normalizedStatus == ProposalStatus.pending ||
                  normalizedStatus == ProposalStatus.submitted);
          final profileStatus =
              auth.profile?['status'] as String? ?? '';
          final canComment = auth.user != null &&
              profileStatus != 'unverified' &&
              profileStatus != 'disabled';
          final canSeeHistory = isAuthor || auth.isAdmin || auth.isModerator;

          final statusItems = <String>[
            ProposalStatus.pending,
            ProposalStatus.submitted,
            ProposalStatus.inProgress,
            ProposalStatus.published,
            ProposalStatus.completed,
            ProposalStatus.closed,
            ProposalStatus.archived,
            ProposalStatus.transferred,
            ProposalStatus.rejected,
          ];

          return Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                Text(
                  data['title'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(data['text'] ?? ''),
                const SizedBox(height: 20),
                // Статус с цветной плашкой
                _StatusBadge(status: normalizedStatus),
                if (data['moderationPublished'] == false)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Не опубликовано для общей ленты и голосования.',
                      style: TextStyle(color: Colors.deepOrange, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),
                // Дата без системной информации (только дд.мм.гггг чч:мм)
                if (createdAt != null)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Создано',
                    value: formatDateTime(createdAt),
                  ),
                if (updatedAt != null)
                  _InfoRow(
                    icon: Icons.update_outlined,
                    label: 'Обновлено',
                    value: formatDateTime(updatedAt),
                  ),
                if (storedDeadline != null)
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Голосование до',
                    value: formatDateTime(storedDeadline),
                  ),
                if (comment != null && comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.comment_outlined,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comment,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _LikesRow(
                    proposalId: widget.id,
                    currentUserId: auth.user!.uid),
                const SizedBox(height: 16),
                _AttachmentsBlock(attachments: data['attachments']),

                // ── Модерация ──
                if (canModerate) ...[
                  const SizedBox(height: 24),
                  Text('Модерация',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Автопроверки — подсказка, не замена решению модератора.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _autoBusy
                        ? null
                        : () async {
                            setState(() => _autoBusy = true);
                            try {
                              final pipe = ClientModerationPipeline(
                                duplicates: FirestoreDuplicateHeuristic(
                                    FirebaseFirestore.instance),
                              );
                              final r = await pipe.runForProposal(
                                proposalId: widget.id,
                                data: data,
                              );
                              if (mounted) setState(() => _autoResult = r);
                            } finally {
                              if (mounted) setState(() => _autoBusy = false);
                            }
                          },
                    icon: _autoBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fact_check_outlined),
                    label: const Text('Автопроверки'),
                  ),
                  if (_autoResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Лексика: ${_autoResult!.profanityOk ? "ок" : "срабатывания: ${_autoResult!.profanityHits}"}\n'
                      'Дубли: score=${_autoResult!.duplicateScore.toStringAsFixed(2)}, '
                      'id: ${_autoResult!.similarProposalIds.join(", ")}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      if (_autoResult != null &&
                          !_autoResult!.recommendedToPublish) {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Публикация'),
                            content: const Text(
                                'Автопроверки не зелёные. Всё равно опубликовать?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Отмена')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Опубликовать')),
                            ],
                          ),
                        );
                        if (ok != true) return;
                      }
                      try {
                        await ProposalsRepository.publishToPublicFeed(
                          proposalId: widget.id,
                          moderatorId: auth.user!.uid,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Опубликовано в общую ленту')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.public),
                    label: const Text('Опубликовать в общую ленту'),
                  ),
                  const SizedBox(height: 16),

                  // Срок голосования
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timer_outlined, size: 18),
                          label: Text(_votingDeadline == null
                              ? 'Установить срок голосования'
                              : 'Срок: ${formatDateTime(_votingDeadline!)}'),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _votingDeadline ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date == null || !mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                  _votingDeadline ?? DateTime.now()),
                            );
                            if (!mounted) return;
                            setState(() {
                              _votingDeadline = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time?.hour ?? 23,
                                time?.minute ?? 59,
                              );
                            });
                          },
                        ),
                      ),
                      if (_votingDeadline != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Сохранить срок',
                          icon: _savingDeadline
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.save_outlined),
                          onPressed: _savingDeadline
                              ? null
                              : () async {
                                  setState(() => _savingDeadline = true);
                                  try {
                                    await ProposalsRepository.proposals()
                                        .doc(widget.id)
                                        .update({
                                      'votingDeadline': Timestamp.fromDate(
                                          _votingDeadline!),
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Срок сохранён')));
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _savingDeadline = false);
                                    }
                                  }
                                },
                        ),
                        IconButton(
                          tooltip: 'Убрать срок',
                          icon: const Icon(Icons.timer_off_outlined),
                          onPressed: () async {
                            await ProposalsRepository.proposals()
                                .doc(widget.id)
                                .update({
                              'votingDeadline': FieldValue.delete(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (mounted) setState(() => _votingDeadline = null);
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Передать в подразделение'),
                    value: _handoverDepartmentId,
                    items: HandoverDepartment.defaults
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(
                        () => _handoverDepartmentId = v ?? _handoverDepartmentId),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ProposalsRepository.markTransferredToDepartment(
                          proposalId: widget.id,
                          departmentId: _handoverDepartmentId,
                          moderatorId: auth.user!.uid,
                          comment: _commentController.text.trim(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Отмечено как переданное')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.forward_to_inbox),
                    label: const Text('Зафиксировать передачу'),
                  ),
                ],

                // ── Редактирование автора ──
                if (canAuthorEdit) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreateProposalPage(proposalId: widget.id),
                            ),
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Редактировать'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Удалить предложение?'),
                                content:
                                    const Text('Действие нельзя отменить.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Отмена')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Удалить')),
                                ],
                              ),
                            );
                            if (ok != true || !context.mounted) return;
                            await ProposalsRepository.deleteProposal(widget.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Удалить'),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Изменение статуса (модератор) ──
                if (canModerate) ...[
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: (_status != null && statusItems.contains(_status))
                        ? _status
                        : ProposalStatus.pending,
                    decoration:
                        const InputDecoration(labelText: 'Изменить статус'),
                    items: statusItems
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(ProposalStatus.label(v)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Комментарий модератора'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final nextStatus = _status ?? ProposalStatus.pending;
                      final reason = _commentController.text.trim();
                      if (nextStatus == ProposalStatus.rejected &&
                          reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Укажите причину отклонения')));
                        return;
                      }
                      try {
                        await ProposalsRepository.setProposalStatusWithHistory(
                          proposalId: widget.id,
                          newStatus: nextStatus,
                          changedById: auth.user!.uid,
                          reason: reason,
                          moderatorCommentForLegacyUi: reason,
                        );
                        if (!mounted) return;
                        setState(() {
                          _status = nextStatus;
                          _lastServerStatus = nextStatus;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Изменения сохранены')));
                      } catch (e) {
                        if (!mounted) return;
                        final msg = e is FirebaseException
                            ? 'Ошибка: ${e.code} ${e.message ?? ''}'
                            : 'Ошибка: $e';
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      }
                    },
                    child: const Text('Сохранить статус'),
                  ),
                ],

                // ── История статусов ──
                if (canSeeHistory) ...[
                  const SizedBox(height: 24),
                  Text('История статусов',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: ProposalsRepository.proposalHistory(widget.id)
                        .orderBy('changedAt', descending: true)
                        .snapshots(),
                    builder: (context, s) {
                      if (!s.hasData) return const LinearProgressIndicator();
                      final docs = s.data!.docs;
                      if (docs.isEmpty) return const Text('Пока пусто');
                      return Column(
                        children: docs.map((d) {
                          final m = d.data();
                          final st = ProposalStatus.label(
                              m['status'] as String? ?? '');
                          final r = (m['reason'] as String?)?.trim();
                          final at =
                              (m['changedAt'] as Timestamp?)?.toDate();
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(st),
                            subtitle: Text([
                              if (at != null) formatDate(at),
                              if (r != null && r.isNotEmpty) r,
                            ].join(' — ')),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],

                // ── Комментарии ──
                const SizedBox(height: 24),
                Text('Комментарии',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('proposals')
                      .doc(widget.id)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, s) {
                    if (!s.hasData) return const LinearProgressIndicator();
                    final docs = s.data!.docs;
                    if (docs.isEmpty) return const Text('Комментариев нет');
                    return Column(
                      children: docs.map((d) {
                        final m = d.data();
                        final text = m['text'] as String? ?? '';
                        final at = (m['createdAt'] as Timestamp?)?.toDate();
                        final who =
                            (m['authorDisplayName'] as String?)?.trim();
                        final aid = m['authorId'] as String? ?? '';
                        final whoLine = (who != null && who.isNotEmpty)
                            ? who
                            : (aid.length >= 8
                                ? 'Пользователь ${aid.substring(0, 8)}…'
                                : 'Пользователь');
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(whoLine,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(text),
                              if (at != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    formatDate(at),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                if (canComment) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newCommentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Добавить комментарий',
                      hintText: 'Поделитесь мнением...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () async {
                        final txt = _newCommentController.text.trim();
                        if (txt.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Введите текст комментария')));
                          return;
                        }
                        final profile = auth.profile;
                        final fullName =
                            (profile?['fullName'] as String?)?.trim();
                        try {
                          await ProposalsRepository.addComment(
                            proposalId: widget.id,
                            userId: auth.user!.uid,
                            text: txt,
                            authorFullName:
                                fullName != null && fullName.isNotEmpty
                                    ? fullName
                                    : null,
                            authorEmail: auth.user?.email,
                          );
                          _newCommentController.clear();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Не удалось отправить: $e')));
                        }
                      },
                      child: const Text('Отправить'),
                    ),
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

// ── Вспомогательные виджеты ──

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status) {
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
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        ProposalStatus.label(status),
        style: TextStyle(
            color: _color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _AttachmentsBlock extends StatelessWidget {
  const _AttachmentsBlock({required this.attachments});
  final Object? attachments;

  @override
  Widget build(BuildContext context) {
    final list = (attachments as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Вложения', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...list.map((a) {
          final name = a['name'] as String? ?? 'file';
          final ct = (a['contentType'] as String?) ?? '';
          final url = a['url'] as String? ?? '';
          final img = imageWidgetForProposalAttachment(a);
          if (img != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  img,
                ],
              ),
            );
          }
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(name),
            subtitle: Text([
              if (ct.isNotEmpty) ct,
              if (url.isNotEmpty) url,
            ].join(' • ')),
          );
        }),
      ],
    );
  }
}

class _LikesRow extends StatelessWidget {
  const _LikesRow(
      {required this.proposalId, required this.currentUserId});
  final String proposalId;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final likesCol = FirebaseFirestore.instance
        .collection('proposals')
        .doc(proposalId)
        .collection('votes');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: likesCol.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final forCount =
            docs.where((d) => (d.data()['value'] as int? ?? 1) == 1).length;
        final againstCount =
            docs.where((d) => (d.data()['value'] as int? ?? 0) == -1).length;
        final userVote =
            docs.where((d) => d.id == currentUserId).toList();
        final voteValue = userVote.isNotEmpty
            ? (userVote.first.data()['value'] as int? ?? 0)
            : 0;
        return Row(
          children: [
            IconButton(
              onPressed: () async {
                try {
                  if (voteValue == 1) {
                    await ProposalsRepository.clearVote(
                        proposalId: proposalId, userId: currentUserId);
                  } else {
                    await ProposalsRepository.setVote(
                        proposalId: proposalId,
                        userId: currentUserId,
                        isFor: true);
                  }
                } on Failure catch (f) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(f.message)));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')));
                  }
                }
              },
              icon: Icon(
                  voteValue == 1 ? Icons.thumb_up : Icons.thumb_up_outlined),
            ),
            Text('$forCount', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () async {
                try {
                  if (voteValue == -1) {
                    await ProposalsRepository.clearVote(
                        proposalId: proposalId, userId: currentUserId);
                  } else {
                    await ProposalsRepository.setVote(
                        proposalId: proposalId,
                        userId: currentUserId,
                        isFor: false);
                  }
                } on Failure catch (f) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(f.message)));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')));
                  }
                }
              },
              icon: Icon(voteValue == -1
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined),
            ),
            Text('$againstCount',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );
      },
    );
  }
}
