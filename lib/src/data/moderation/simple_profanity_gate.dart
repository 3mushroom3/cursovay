import '../../domain/moderation/automated_moderation_result.dart';

/// Простейший локальный фильтр «нецензурной лексики».
///
/// Почему локально, а не внешний API: для production-продукта обычно подключают
/// облачный сервис (Perspective API, собственный ML) или серверные Cloud Functions,
/// чтобы не тащить словари в клиент и не раскрывать эвристики. Для клиентского
/// приложения это — **первый барьер** и подсказка модератору, а не юридически
/// значимая модерация.
///
/// Список намеренно короткий: расширяется через конфиг/Remote Config/сервер.
class SimpleProfanityGate {
  SimpleProfanityGate({List<String>? extraWords})
      : _words = {..._builtinRu, ...?extraWords?.map((e) => e.toLowerCase())};

  final Set<String> _words;

  /// Минимальный набор шаблонов; реальный проект заменяет на полноценный словарь.
  static const Set<String> _builtinRu = {
    'хрен',
    'блин',
    // Не включаем явные матные корни в репозиторий — в проде словарь хранится
    // на сервере. Здесь оставляем точку расширения через [extraWords].
  };

  /// Возвращает список «совпадений» (подстроки), если фильтр сработал.
  List<String> findHits(String text) {
    final t = text.toLowerCase();
    final hits = <String>[];
    for (final w in _words) {
      if (w.isEmpty) continue;
      if (t.contains(w)) hits.add(w);
    }
    return hits;
  }

  /// Только проверка лексики; дубли подмешиваются отдельным шагом пайплайна.
  AutomatedModerationResult analyze(String title, String body) {
    final hits = findHits('${title.trim()}\n${body.trim()}');
    return AutomatedModerationResult(
      profanityOk: hits.isEmpty,
      profanityHits: hits,
      duplicateScore: 0,
      similarProposalIds: const [],
    );
  }

  /// Объединяет результат эвристики дублей с результатом лексики.
  AutomatedModerationResult mergeDuplicate(
    AutomatedModerationResult profanityOnly,
    AutomatedModerationResult duplicateOnly,
  ) {
    return AutomatedModerationResult(
      profanityOk: profanityOnly.profanityOk,
      profanityHits: profanityOnly.profanityHits,
      duplicateScore: duplicateOnly.duplicateScore,
      similarProposalIds: duplicateOnly.similarProposalIds,
    );
  }
}
