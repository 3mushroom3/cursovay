import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../attachment_image.dart';
import '../models/proposal_status.dart';
import '../models/user_roles.dart';
import '../repositories/proposals_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final normalizedRole = UserRoles.normalize(auth.profile?['role']);
    final canEdit =
        normalizedRole == UserRoles.teacher || normalizedRole == UserRoles.admin;

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
          final createdAt = data['createdAt'] as Timestamp?;
          final updatedAt = data['updatedAt'] as Timestamp?;

          final normalizedStatus = ProposalStatus.normalize(status);
          if (_lastServerStatus != normalizedStatus) {
            final hasUnsavedLocalStatusChange =
                _status != null && _status != _lastServerStatus;
            _lastServerStatus = normalizedStatus;
            // Do not overwrite user-selected value before explicit save.
            if (!hasUnsavedLocalStatusChange) {
              _status = normalizedStatus;
            }
          }
          if (_commentController.text.isEmpty && comment != null) {
            _commentController.text = comment;
          }

          final authorId = data['authorId'] as String?;
          final isAuthor = authorId != null && authorId == auth.user?.uid;
          final canAuthorEdit = isAuthor &&
              (normalizedStatus == ProposalStatus.pending);
          final profileStatus = auth.profile?['status'] as String? ?? '';
          final canComment = auth.user != null &&
              profileStatus != 'unverified' &&
              profileStatus != 'disabled';
          final canSeeHistory = isAuthor || auth.isAdmin;

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
                const SizedBox(height: 24),
                Tooltip(
                  message: 'pending: на рассмотрении; in_progress: в работе; completed: завершено; rejected: отклонено',
                  child: Text('Статус: ${ProposalStatus.label(normalizedStatus)}'),
                ),
                if (createdAt != null)
                  Text('Создано: ${createdAt.toDate()}'),
                if (updatedAt != null)
                  Text('Обновлено: ${updatedAt.toDate()}'),
                if (comment != null && comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Комментарий: $comment'),
                  ),
                const SizedBox(height: 16),
                _LikesRow(proposalId: widget.id, currentUserId: auth.user!.uid),
                const SizedBox(height: 16),
                _AttachmentsBlock(attachments: data['attachments']),
                if (canAuthorEdit) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateProposalPage(proposalId: widget.id),
                              ),
                            );
                          },
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
                                content: const Text(
                                  'Действие нельзя отменить.',
                                ),
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
                if (canEdit) ...[
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration:
                        const InputDecoration(labelText: 'Изменить статус'),
                    items: const [
                      DropdownMenuItem(
                          value: ProposalStatus.pending,
                          child: Text('На рассмотрении')),
                      DropdownMenuItem(
                          value: ProposalStatus.inProgress, child: Text('В работе')),
                      DropdownMenuItem(
                          value: ProposalStatus.completed, child: Text('Завершено')),
                      DropdownMenuItem(
                          value: ProposalStatus.rejected, child: Text('Отклонено')),
                    ],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Комментарий'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final nextStatus = _status ?? ProposalStatus.pending;
                      final reason = _commentController.text.trim();
                      if (nextStatus == ProposalStatus.rejected && reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Укажите причину отклонения')),
                        );
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
                            content: Text('Изменения сохранены'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        final msg = e is FirebaseException
                            ? 'Не удалось сохранить: ${e.code} ${e.message ?? ''}'
                            : 'Не удалось сохранить: $e';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                          ),
                        );
                      }
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
                if (canSeeHistory) ...[
                const SizedBox(height: 24),
                Text(
                  'История статусов',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ProposalsRepository.proposalHistory(widget.id)
                      .orderBy('changedAt', descending: true)
                      .snapshots(),
                  builder: (context, s) {
                    if (!s.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final docs = s.data!.docs;
                    if (docs.isEmpty) {
                      return const Text('Пока пусто');
                    }
                    return Column(
                      children: docs.map((d) {
                        final m = d.data();
                        final st = ProposalStatus.label(m['status'] as String? ?? '');
                        final r = (m['reason'] as String?)?.trim();
                        final at = (m['changedAt'] as Timestamp?)?.toDate();
                        final by = (m['changedById'] as String?) ?? '';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(st),
                          subtitle: Text([
                            if (at != null) _relativeTime(at),
                            if (by.isNotEmpty) 'изменил: $by',
                            if (r != null && r.isNotEmpty) r,
                          ].join(' — ')),
                        );
                      }).toList(),
                    );
                  },
                ),],
                const SizedBox(height: 24),
                Text(
                  'Комментарии',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                        final who = (m['authorDisplayName'] as String?)?.trim();
                        final aid = m['authorId'] as String? ?? '';
                        final whoLine = (who != null && who.isNotEmpty)
                            ? who
                            : (aid.length >= 8
                                ? 'Пользователь ${aid.substring(0, 8)}…'
                                : 'Пользователь');
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            whoLine,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(text),
                              if (at != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _relativeTime(at),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
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
                              content: Text('Введите текст комментария'),
                            ),
                          );
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
                            SnackBar(content: Text('Не удалось отправить: $e')),
                          );
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
                  Text(name, style: Theme.of(context).textTheme.bodyMedium),
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
            subtitle: Text(
              [
                if (ct.isNotEmpty) ct,
                if (url.isNotEmpty) url,
              ].join(' • '),
            ),
          );
        }),
      ],
    );
  }
}

class _LikesRow extends StatelessWidget {
  const _LikesRow({required this.proposalId, required this.currentUserId});

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
        final count = docs.length;
        final liked = docs.any((d) => d.id == currentUserId);
        return Row(
          children: [
            IconButton(
              onPressed: () async {
                if (liked) {
                  await ProposalsRepository.removeLike(
                    proposalId: proposalId,
                    userId: currentUserId,
                  );
                } else {
                  await ProposalsRepository.addLike(
                    proposalId: proposalId,
                    userId: currentUserId,
                  );
                }
              },
              icon: Icon(liked ? Icons.how_to_vote : Icons.how_to_vote_outlined),
            ),
            Text('Голосов: $count'),
          ],
        );
      },
    );
  }
}

String _relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
  if (diff.inDays < 1) return '${diff.inHours} ч назад';
  return '${diff.inDays} дн назад';
}