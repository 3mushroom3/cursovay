import 'package:cloud_firestore/cloud_firestore.dart';

import '../attachment_image.dart';
import '../domain/policies/voting_policy.dart';
import '../models/proposal_status.dart';

/// Firestore access layer for proposals domain.
///
/// Note: This repository intentionally keeps the mapping simple and backward
/// compatible with the existing prototype fields (e.g. `comment`).
class ProposalsRepository {
  static CollectionReference<Map<String, dynamic>> proposals() {
    return FirebaseFirestore.instance.collection('proposals');
  }

  static CollectionReference<Map<String, dynamic>> proposalHistory(
    String proposalId,
  ) {
    return proposals().doc(proposalId).collection('history');
  }

  static Future<DocumentReference<Map<String, dynamic>>> createProposal({
    required String title,
    required String text,
    required String authorId,
    String? categoryId,
    String? visibility,
    String? status,
  }) async {
    final doc = await proposals().add({
      'title': title,
      'text': text,
      'authorId': authorId,
      'categoryId': categoryId ?? 'uncategorized',
      'visibility': visibility ?? 'private',
      // Новые обращения по умолчанию ждут модерации для попадания в общую ленту.
      'status': status ?? ProposalStatus.submitted,
      // `null` в старых документах трактуем как «уже опубликовано при public».
      'moderationPublished': false,
      'attachments': [],
      'votesForCount': 0,
      'votesAgainstCount': 0,
      'votesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Kept for backward compatibility with the current UI.
      'comment': '',
    });

    return doc;
  }

  static Future<void> updateProposalContent({
    required String proposalId,
    required String title,
    required String text,
    required String categoryId,
  }) async {
    await proposals().doc(proposalId).update({
      'title': title,
      'text': text,
      'categoryId': categoryId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> appendAttachments({
    required String proposalId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return;
    final snap = await proposals().doc(proposalId).get();
    final data = snap.data();
    final existing = (data?['attachments'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    final merged = [...existing, ...items];
    final totalB64 = estimateInlineBase64TotalLength(merged);
    if (totalB64 > kMaxProposalAttachmentsInlineBase64Chars) {
      throw FormatException(
        'Суммарный размер вложений слишком большой для одного документа Firestore '
        '(лимит ~500 КБ изображений в base64). Уменьшите или удалите часть фото.',
      );
    }
    await proposals().doc(proposalId).update({
      'attachments': merged,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteProposal(String proposalId) async {
    await proposals().doc(proposalId).delete();
  }

  /// Updates proposal status and writes a history record.
  ///
  /// For диплома: `reason` corresponds to the required moderator/assignee
  /// explanation when rejecting or requesting clarification.
  static Future<void> setProposalStatusWithHistory({
    required String proposalId,
    required String newStatus,
    required String changedById,
    String? reason,
    String? moderatorCommentForLegacyUi,
  }) async {
    // Normalize legacy "at work" into "at_work" for consistent storage.
    final normalizedStatus = ProposalStatus.normalize(newStatus);
    final textReason = (reason ?? moderatorCommentForLegacyUi ?? '').trim();

    // 1) Apply status update first (critical action for moderator workflow).
    final pRef = proposals().doc(proposalId);
    final patch = <String, dynamic>{
      'status': normalizedStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      // Backward compatible field used by the current detail UI.
      'comment': textReason,
    };
    // Статус «опубликовано» в нашей модели всегда означает доступ в общую ленту.
    if (normalizedStatus == ProposalStatus.published) {
      patch['moderationPublished'] = true;
      patch['visibility'] = 'public';
    }
    await pRef.update(patch);
    // Ensure server persisted the new status (helps diagnose silent failures).
    final persisted = await pRef.get();
    final persistedStatus =
        ProposalStatus.normalize(persisted.data()?['status'] as String?);
    if (persistedStatus != normalizedStatus) {
      throw StateError(
        'Статус не обновился на сервере (ожидалось: $normalizedStatus, фактически: $persistedStatus)',
      );
    }

    // 2) Try to write history entry; if it fails, do not roll back status.
    try {
      await proposalHistory(proposalId).add({
        'status': normalizedStatus,
        'reason': textReason,
        'changedById': changedById,
        'changedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical for status change; can be diagnosed separately.
    }
  }

  /// Публикация в общую ленту после решения модератора (ручной шаг).
  ///
  /// Автопроверки вызываются отдельно (см. [ClientModerationPipeline]), чтобы
  /// модератор видел отчёт до необратимого для пользователя изменения статуса.
  static Future<void> publishToPublicFeed({
    required String proposalId,
    required String moderatorId,
  }) async {
    await proposals().doc(proposalId).update({
      'moderationPublished': true,
      'visibility': 'public',
      'status': ProposalStatus.published,
      'moderatedById': moderatorId,
      'moderatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Передача в структурное подразделение (фиксируем id из справочника).
  static Future<void> markTransferredToDepartment({
    required String proposalId,
    required String departmentId,
    required String moderatorId,
    String? comment,
  }) async {
    await proposals().doc(proposalId).update({
      'status': ProposalStatus.transferred,
      'handoverDepartmentId': departmentId,
      'handoverMarkedById': moderatorId,
      'handoverMarkedAt': FieldValue.serverTimestamp(),
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markArchived({
    required String proposalId,
    required String moderatorId,
  }) async {
    await proposals().doc(proposalId).update({
      'status': ProposalStatus.archived,
      'archivedById': moderatorId,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Голос "за" / "против".
  ///
  /// Храним значение голоса в `votes/{userId}.value`:
  /// - `1`  => за
  /// - `-1` => против
  static Future<void> setVote({
    required String proposalId,
    required String userId,
    required bool isFor,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final pRef = proposals().doc(proposalId);
      final vRef = pRef.collection('votes').doc(userId);
      final pSnap = await tx.get(pRef);
      final data = pSnap.data() ?? <String, dynamic>{};
      VotingPolicy.ensureCanVote(
        voterId: userId,
        proposalAuthorId: data['authorId'] as String?,
      );
      final prevVoteSnap = await tx.get(vRef);
      final prevValue = (prevVoteSnap.data()?['value'] as int?) ?? 0;
      final nextValue = isFor ? 1 : -1;
      if (prevValue == nextValue) return;

      var forCount = (data['votesForCount'] as int?) ?? 0;
      var againstCount = (data['votesAgainstCount'] as int?) ?? 0;

      if (prevValue == 1) forCount = forCount > 0 ? forCount - 1 : 0;
      if (prevValue == -1) againstCount = againstCount > 0 ? againstCount - 1 : 0;
      if (nextValue == 1) forCount += 1;
      if (nextValue == -1) againstCount += 1;

      tx.set(vRef, {
        'value': nextValue,
        'votedAt': FieldValue.serverTimestamp(),
      });
      final patch = <String, dynamic>{
        'votesForCount': forCount,
        'votesAgainstCount': againstCount,
        // Backward compatible aggregate: score = за - против.
        'votesCount': forCount - againstCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Автопродвижение: при наборе 10+ голосов «за» предложение переходит в работу
      const autoPromoteThreshold = 10;
      final currentStatus =
          ProposalStatus.normalize(data['status'] as String?);
      if (forCount >= autoPromoteThreshold &&
          currentStatus == ProposalStatus.published) {
        patch['status'] = ProposalStatus.inProgress;
        patch['autoPromotedAt'] = FieldValue.serverTimestamp();
      }
      tx.update(pRef, patch);
    });
  }

  static Future<void> clearVote({
    required String proposalId,
    required String userId,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final pRef = proposals().doc(proposalId);
      final vRef = pRef.collection('votes').doc(userId);
      final pSnap = await tx.get(pRef);
      final data = pSnap.data() ?? <String, dynamic>{};
      VotingPolicy.ensureCanVote(
        voterId: userId,
        proposalAuthorId: data['authorId'] as String?,
      );
      final prevVoteSnap = await tx.get(vRef);
      if (!prevVoteSnap.exists) return;
      final prevValue = (prevVoteSnap.data()?['value'] as int?) ?? 0;

      var forCount = (data['votesForCount'] as int?) ?? 0;
      var againstCount = (data['votesAgainstCount'] as int?) ?? 0;
      if (prevValue == 1) forCount = forCount > 0 ? forCount - 1 : 0;
      if (prevValue == -1) againstCount = againstCount > 0 ? againstCount - 1 : 0;

      tx.delete(vRef);
      tx.update(pRef, {
        'votesForCount': forCount,
        'votesAgainstCount': againstCount,
        'votesCount': forCount - againstCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Подпись в ленте комментариев: ФИО из профиля или email.
  static String composeAuthorDisplayName({
    String? fullName,
    String? email,
  }) {
    final n = (fullName ?? '').trim();
    if (n.isNotEmpty) {
      return n.length > 120 ? '${n.substring(0, 120)}…' : n;
    }
    final e = (email ?? '').trim();
    if (e.isNotEmpty) return e;
    return 'Участник';
  }

  static Future<void> addComment({
    required String proposalId,
    required String userId,
    required String text,
    String? authorFullName,
    String? authorEmail,
  }) async {
    final content = text.trim();
    if (content.isEmpty) return;
    if (content.length > 4000) {
      throw FormatException('Комментарий слишком длинный (максимум 4000 символов).');
    }

    final authorDisplayName = composeAuthorDisplayName(
      fullName: authorFullName,
      email: authorEmail,
    );

    await proposals()
        .doc(proposalId)
        .collection('comments')
        .add({
      'authorId': userId,
      'authorDisplayName': authorDisplayName,
      'text': content,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

