/// Статусы жизненного цикла предложения.
///
/// Часть значений — наследие прототипа (`pending`, `in_progress`, …).
/// Новые статусы закрывают требования ТЗ: архив, передача в подразделение,
/// явная публикация после модерации и т.д.
class ProposalStatus {
  // --- Наследие прототипа (сохраняем строки для совместимости с Firestore) ---
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String rejected = 'rejected';

  // --- Расширения под ТЗ ---
  /// Новое предложение, ещё не прошло модерацию для публичной ленты.
  static const String submitted = 'submitted';

  /// Опубликовано модератором в общий доступ (см. также `moderationPublished`).
  static const String published = 'published';

  /// Закрыто по смыслу «работа завершена / вопрос снят».
  static const String closed = 'closed';

  /// Архив (устаревшие обращения).
  static const String archived = 'archived';

  /// Передано в другое подразделение (`handoverDepartmentId` в документе).
  static const String transferred = 'transferred';

  static String normalize(String? status) {
    if (status == null || status.isEmpty) return pending;
    switch (status) {
      case 'new':
      case 'review':
      case 'needs_info':
        return pending;
      case submitted:
        return submitted;
      case 'at_work':
      case 'at work':
        return inProgress;
      case completed:
      case rejected:
      case published:
      case closed:
      case archived:
      case transferred:
        return status;
      case pending:
      case inProgress:
        return status;
      default:
        return pending;
    }
  }

  static String label(String status) {
    switch (normalize(status)) {
      case submitted:
        return 'Новое (ожидает модерации)';
      case pending:
        return 'На рассмотрении';
      case inProgress:
        return 'В работе';
      case completed:
        return 'Завершено';
      case rejected:
        return 'Отклонено';
      case published:
        return 'Опубликовано (публичная лента)';
      case closed:
        return 'Закрыто';
      case archived:
        return 'Архив';
      case transferred:
        return 'Передано в подразделение';
      default:
        return status;
    }
  }

  static const List<String> values = [
    pending,
    submitted,
    inProgress,
    completed,
    rejected,
    published,
    closed,
    archived,
    transferred,
  ];
}
