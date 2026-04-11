class ProposalStatus {
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String rejected = 'rejected';

  static String normalize(String? status) {
    if (status == null || status.isEmpty) return pending;
    switch (status) {
      case 'new':
      case 'review':
      case 'needs_info':
        return pending;
      case 'at_work':
      case 'at work':
        return inProgress;
      case completed:
      case rejected:
        return status;
      default:
        return pending;
    }
  }

  static String label(String status) {
    switch (normalize(status)) {
      case pending:
        return 'На рассмотрении';
      case inProgress:
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
    pending,
    inProgress,
    completed,
    rejected,
  ];
}

