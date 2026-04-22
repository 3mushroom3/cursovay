import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/moderation/automated_moderation_result.dart';

/// Эвристика поиска похожих предложений в Firestore.
///
/// Алгоритм намеренно простой (Jaccard по токенам): он масштабируется на сотни
/// документов и не требует ML. Альтернативы:
/// * Cloud Function + embeddings (Vertex AI) — лучше качество, выше стоимость;
/// * отдельный поисковый индекс (Algolia / Typesense);
/// * n-gram + MinHash на сервере.
class FirestoreDuplicateHeuristic {
  FirestoreDuplicateHeuristic(this._firestore);

  final FirebaseFirestore _firestore;

  /// Сканирует последние [limit] документов (без сложных индексов).
  Future<AutomatedModerationResult> scan({
    required String title,
    required String body,
    required String? categoryId,
    required String excludeProposalId,
    int limit = 80,
  }) async {
    final q = _firestore
        .collection('proposals')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final snap = await q.get();
    final combined = '${title.trim()}\n${body.trim()}'.toLowerCase();
    final targetTokens = _tokenize(combined);

    var best = 0.0;
    final similar = <String>[];

    for (final doc in snap.docs) {
      if (doc.id == excludeProposalId) continue;
      final d = doc.data();
      final otherCat = d['categoryId'] as String?;
      if (categoryId != null &&
          otherCat != null &&
          categoryId.isNotEmpty &&
          otherCat.isNotEmpty &&
          categoryId != otherCat) {
        // Ускоряем и повышаем точность: дубли чаще в одной категории.
        continue;
      }
      final t = '${d['title'] ?? ''}\n${d['text'] ?? ''}'.toLowerCase();
      final score = jaccard(targetTokens, _tokenize(t));
      if (score > best) best = score;
      if (score >= 0.45) similar.add(doc.id);
    }

    return AutomatedModerationResult(
      profanityOk: true,
      profanityHits: const [],
      duplicateScore: best,
      similarProposalIds: similar,
    );
  }

  /// Удобная обёртка для экрана модерации (id может быть пустым при создании).
  Future<AutomatedModerationResult> scanForProposalDoc({
    required String proposalId,
    required Map<String, dynamic> data,
  }) async {
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final categoryId = data['categoryId'] as String?;
    return scan(
      title: title,
      body: text,
      categoryId: categoryId,
      excludeProposalId: proposalId,
    );
  }

  static Set<String> _tokenize(String s) {
    final buf = StringBuffer();
    for (final c in s.runes) {
      final ch = String.fromCharCode(c);
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
        buf.write(ch.toLowerCase());
      } else {
        buf.write(' ');
      }
    }
    final parts = buf.toString().split(RegExp(r'\s+')).where((e) => e.length > 2);
    return parts.toSet();
  }

  /// Коэффициент Жаккара по множествам токенов.
  static double jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final inter = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) return 0;
    return inter / union;
  }
}
