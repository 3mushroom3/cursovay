import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../domain/moderation/public_feed_policy.dart';
import '../models/proposal_status.dart';
import '../repositories/proposals_repository.dart';
import '../domain/core/failure.dart';
import 'detail_page.dart';

/// Отдельный экран голосования: только материалы, доступные для публичного участия.
///
/// Почему отдельная страница, а не только иконка в карточке: по ТЗ голосование —
/// отдельный сценарий; так проще ограничить выборку и не смешивать с «моими черновиками».
class VotingPage extends StatelessWidget {
  const VotingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.user?.uid;

    if (!auth.profileLoaded || uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
      appBar: AppBar(
        title: const Text('Голосование'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('proposals')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.where((d) {
            final data = d.data();
            return PublicFeedPolicy.isEligibleForPublicVoting(
              data: data,
              voterId: uid,
            );
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Нет предложений, за которые можно голосовать.\n'
                  'Появятся после публикации модератором.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final title = data['title'] as String? ?? '';
              final st = ProposalStatus.label(data['status'] as String? ?? '');
              final votesFor = (data['votesForCount'] as int?) ?? 0;
              final votesAgainst = (data['votesAgainstCount'] as int?) ?? 0;
              final likesCol = FirebaseFirestore.instance
                  .collection('proposals')
                  .doc(doc.id)
                  .collection('votes');

              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('$st · за: $votesFor · против: $votesAgainst'),
                  trailing: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: likesCol.snapshots(),
                    builder: (context, vs) {
                      final userDoc = vs.data?.docs.where((e) => e.id == uid).toList();
                      final voteValue = userDoc != null && userDoc.isNotEmpty
                          ? (userDoc.first.data()['value'] as int? ?? 0)
                          : 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: voteValue == 1 ? 'Снять голос ЗА' : 'Голос ЗА',
                            icon: Icon(
                              voteValue == 1
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                            ),
                            onPressed: () async {
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
                          IconButton(
                            tooltip: voteValue == -1 ? 'Снять голос ПРОТИВ' : 'Голос ПРОТИВ',
                            icon: Icon(
                              voteValue == -1
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                            ),
                            onPressed: () async {
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
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DetailPage(id: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
