class ProposalStatus {
  // Firestore values (string keys).
  static const String draft = 'new'; // current app uses 'new' as initial state
  static const String review = 'review';
  static const String needsInfo = 'needs_info';
  static const String inWork = 'at_work';
  static const String completed = 'completed';
  static const String rejected = 'rejected';

  // Legacy normalization for already stored proposals (in app earlier used 'at work').
  static const String inWorkLegacy = 'at work';

  static String normalize(String? status) {
    if (status == null) return '';
    return status == inWorkLegacy ? inWork : status;
  }

  static String label(String status) {
    switch (normalize(status)) {
      case draft:
        return 'Новые (черновик)';
      case review:
        return 'На рассмотрении';
      case needsInfo:
        return 'Нужно уточнение';
      case inWork:
        return 'В работе';
      case completed:
        return 'Завершено';
      case rejected:
        return 'Отклонено';
      default:
        return status;
    }
  }

  static const List<String> values = [
    draft,
    review,
    needsInfo,
    inWork,
    completed,
    rejected
  ];
}

