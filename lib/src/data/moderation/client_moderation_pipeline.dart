import '../../domain/moderation/automated_moderation_result.dart';
import 'firestore_duplicate_heuristic.dart';
import 'simple_profanity_gate.dart';

/// Клиентский пайплайн автопроверок перед публикацией.
///
/// В production тяжёлую часть обычно переносят в Cloud Functions (секреты,
/// полные словари, единая политика). Здесь — рабочий каркас без «игрушечной»
/// логики в UI: UI вызывает один метод и получает структурированный отчёт.
class ClientModerationPipeline {
  ClientModerationPipeline({
    SimpleProfanityGate? profanity,
    required FirestoreDuplicateHeuristic duplicates,
  })  : _profanity = profanity ?? SimpleProfanityGate(),
        _duplicates = duplicates;

  final SimpleProfanityGate _profanity;
  final FirestoreDuplicateHeuristic _duplicates;

  Future<AutomatedModerationResult> runForProposal({
    required String proposalId,
    required Map<String, dynamic> data,
  }) async {
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final prof = _profanity.analyze(title, text);
    final dup = await _duplicates.scanForProposalDoc(
      proposalId: proposalId,
      data: data,
    );
    return _profanity.mergeDuplicate(prof, dup);
  }
}
