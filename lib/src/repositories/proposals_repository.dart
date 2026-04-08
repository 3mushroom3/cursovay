import 'package:cloud_firestore/cloud_firestore.dart';

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
      'status': status ?? ProposalStatus.draft,
      'attachments': [],
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
    await proposals().doc(proposalId).update({
      'attachments': [...existing, ...items],
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
    await pRef.update({
      'status': normalizedStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      // Backward compatible field used by the current detail UI.
      'comment': textReason,
    });
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

  static Future<void> addLike({
    required String proposalId,
    required String userId,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final pRef = proposals().doc(proposalId);
      final lRef = pRef.collection('likes').doc(userId);
      final pSnap = await tx.get(pRef);
      final data = pSnap.data() ?? <String, dynamic>{};
      final current = (data['likesCount'] as int?) ?? 0;
      final exists = await tx.get(lRef);
      if (!exists.exists) {
        tx.set(lRef, {'likedAt': FieldValue.serverTimestamp()});
        tx.update(pRef, {
          'likesCount': current + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static Future<void> removeLike({
    required String proposalId,
    required String userId,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final pRef = proposals().doc(proposalId);
      final lRef = pRef.collection('likes').doc(userId);
      final pSnap = await tx.get(pRef);
      final data = pSnap.data() ?? <String, dynamic>{};
      final current = (data['likesCount'] as int?) ?? 0;
      final lSnap = await tx.get(lRef);
      if (lSnap.exists) {
        tx.delete(lRef);
        tx.update(pRef, {
          'likesCount': current > 0 ? current - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static Future<void> addComment({
    required String proposalId,
    required String userId,
    required String text,
  }) async {
    final content = text.trim();
    if (content.isEmpty) return;

    await proposals()
        .doc(proposalId)
        .collection('comments')
        .add({
      'authorId': userId,
      'text': content,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

