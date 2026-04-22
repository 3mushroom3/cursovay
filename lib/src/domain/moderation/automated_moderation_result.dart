/// Результат автоматических проверок перед публикацией модератором.
///
/// Это не «вердикт сети», а вспомогательный сигнал: финальное решение всё равно
/// за человеком (требование ТЗ). Автоматика снижает риск ошибок и ускоряет работу.
class AutomatedModerationResult {
  const AutomatedModerationResult({
    required this.profanityOk,
    required this.profanityHits,
    required this.duplicateScore,
    required this.similarProposalIds,
  });

  /// Нет срабатываний по грубому локальному фильтру.
  final bool profanityOk;

  /// Найденные фрагменты/шаблоны (для отчёта модератору).
  final List<String> profanityHits;

  /// 0..1 — насколько текст похож на уже существующие заявки (эвристика).
  final double duplicateScore;

  /// Id документов с высоким сходством (для ручной проверки дублей).
  final List<String> similarProposalIds;

  bool get hasDuplicateRisk => duplicateScore >= 0.35 || similarProposalIds.isNotEmpty;

  /// Рекомендация автоматики: можно ли безопасно публиковать без предупреждений.
  bool get recommendedToPublish => profanityOk && !hasDuplicateRisk;
}
