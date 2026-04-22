import '../core/failure.dart';

/// Правила голосования (доменная политика, без Firestore).
///
/// Централизуем условия здесь, чтобы не дублировать проверки в UI и репозитории
/// и чтобы при смене правил (например «голосование только после N часов»)
/// менять одно место.
class VotingPolicy {
  const VotingPolicy._();

  /// Проверка перед записью голоса в БД.
  ///
  /// [authorId] — автор предложения; голосовать за своё нельзя (требование ТЗ).
  static void ensureCanVote({
    required String voterId,
    required String? proposalAuthorId,
  }) {
    if (proposalAuthorId != null && proposalAuthorId == voterId) {
      throw const Failure(
        'Нельзя голосовать за собственное предложение.',
        code: 'vote-own-proposal',
      );
    }
  }
}
