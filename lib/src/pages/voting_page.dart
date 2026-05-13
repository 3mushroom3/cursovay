import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../domain/moderation/public_feed_policy.dart';
import '../models/proposal_status.dart';
import '../repositories/proposals_repository.dart';
import '../domain/core/failure.dart';
import '../utils/date_format.dart';
import '../widgets/dgtu_background.dart';
import 'detail_page.dart';

class VotingPage extends StatelessWidget {
  const VotingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.user?.uid;

    if (!auth.profileLoaded || uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileStatus = auth.profile?['status'] ?? '';
    if (profileStatus == 'unverified' || profileStatus == 'disabled') {
      return const Scaffold(
        body: Center(
          child: Text('Голосование доступно после подтверждения профиля'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Голосование')),
      body: DgtuBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('proposals')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allDocs = snapshot.data!.docs.where((d) {
              return PublicFeedPolicy.isEligibleForPublicVoting(
                data: d.data(),
                voterId: uid,
              );
            }).toList();

            if (allDocs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Нет предложений для голосования.\n'
                    'Появятся после публикации модератором.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Разделяем на «актуальные» (с дедлайном) и остальные
            final now = DateTime.now();
            final active = allDocs.where((d) {
              final dl = (d.data()['votingDeadline'] as Timestamp?)?.toDate();
              return dl != null && dl.isAfter(now);
            }).toList();
            final regular = allDocs.where((d) {
              final dl = (d.data()['votingDeadline'] as Timestamp?)?.toDate();
              return dl == null || !dl.isAfter(now);
            }).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (active.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.how_to_vote, size: 14,
                                  color: Colors.white),
                              SizedBox(width: 6),
                              Text('Активные голосования',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...active.map((doc) => _VotingCard(
                        doc: doc,
                        uid: uid,
                        isActive: true,
                      )),
                  const Divider(height: 24),
                ],
                if (regular.isNotEmpty) ...[
                  if (active.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Все предложения',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  ...regular.map((doc) => _VotingCard(
                        doc: doc,
                        uid: uid,
                        isActive: false,
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VotingCard extends StatelessWidget {
  const _VotingCard({
    required this.doc,
    required this.uid,
    required this.isActive,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String uid;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title'] as String? ?? '';
    final st = ProposalStatus.label(data['status'] as String? ?? '');
    final votesFor = (data['votesForCount'] as int?) ?? 0;
    final votesAgainst = (data['votesAgainstCount'] as int?) ?? 0;
    final deadline = (data['votingDeadline'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final deadlinePassed = deadline != null && deadline.isBefore(now);
    final votesCol = FirebaseFirestore.instance
        .collection('proposals')
        .doc(doc.id)
        .collection('votes');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.teal, width: 1.5),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => DetailPage(id: doc.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(st,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
              if (deadline != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      deadlinePassed ? Icons.timer_off : Icons.timer_outlined,
                      size: 14,
                      color: deadlinePassed ? Colors.red : Colors.teal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deadlinePassed
                          ? 'Голосование завершено ${formatDate(deadline)}'
                          : 'До ${formatDateTime(deadline)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: deadlinePassed ? Colors.red : Colors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: votesCol.snapshots(),
                builder: (context, vs) {
                  final userDoc = vs.data?.docs
                      .where((e) => e.id == uid)
                      .toList();
                  final voteValue = userDoc != null && userDoc.isNotEmpty
                      ? (userDoc.first.data()['value'] as int? ?? 0)
                      : 0;

                  final total = votesFor + votesAgainst;
                  final pctFor = total > 0
                      ? (votesFor / total * 100).toStringAsFixed(0)
                      : '0';
                  final pctAgainst = total > 0
                      ? (votesAgainst / total * 100).toStringAsFixed(0)
                      : '0';

                  return Column(
                    children: [
                      // Прогресс-бар
                      if (total > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              Flexible(
                                flex: votesFor,
                                child: Container(height: 6, color: Colors.teal),
                              ),
                              Flexible(
                                flex: votesAgainst,
                                child:
                                    Container(height: 6, color: Colors.red.shade300),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _VoteButton(
                            icon: voteValue == 1
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            label: '$votesFor ($pctFor%)',
                            color: Colors.teal,
                            active: voteValue == 1,
                            enabled: !deadlinePassed,
                            onTap: () async {
                              try {
                                if (voteValue == 1) {
                                  await ProposalsRepository.clearVote(
                                    proposalId: doc.id,
                                    userId: uid,
                                  );
                                } else {
                                  await ProposalsRepository.setVote(
                                    proposalId: doc.id,
                                    userId: uid,
                                    isFor: true,
                                  );
                                }
                              } on Failure catch (f) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(f.message)),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _VoteButton(
                            icon: voteValue == -1
                                ? Icons.thumb_down
                                : Icons.thumb_down_outlined,
                            label: '$votesAgainst ($pctAgainst%)',
                            color: Colors.red,
                            active: voteValue == -1,
                            enabled: !deadlinePassed,
                            onTap: () async {
                              try {
                                if (voteValue == -1) {
                                  await ProposalsRepository.clearVote(
                                    proposalId: doc.id,
                                    userId: uid,
                                  );
                                } else {
                                  await ProposalsRepository.setVote(
                                    proposalId: doc.id,
                                    userId: uid,
                                    isFor: false,
                                  );
                                }
                              } on Failure catch (f) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(f.message)),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled ? color : Colors.grey,
          side: BorderSide(
              color: active ? color : Colors.grey.shade300,
              width: active ? 1.5 : 1),
          backgroundColor: active ? color.withOpacity(0.08) : null,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
