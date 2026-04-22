/// Подразделение, куда модератор может «передать» предложение после обработки.
///
/// Хранится как справочник в коде (стабильные `id` для поля Firestore
/// `handoverDepartmentId`). Альтернатива — отдельная коллекция `departments`
/// в Firestore: удобнее редактировать без релиза приложения, но для ВКР/ТЗ
/// часто достаточно фиксированного перечня с понятными идентификаторами.
class HandoverDepartment {
  const HandoverDepartment({
    required this.id,
    required this.title,
    this.description = '',
  });

  final String id;
  final String title;
  final String description;

  /// Список по умолчанию — примерный набор для университета; при необходимости
  /// расширяется без ломки схемы: новый `id` + новая строка в UI.
  static const List<HandoverDepartment> defaults = [
    HandoverDepartment(
      id: 'youth_policy',
      title: 'Отдел молодёжной политики',
      description: 'Вопросы студенческой активности, молодёжных инициатив',
    ),
    HandoverDepartment(
      id: 'dormitory',
      title: 'Управление общежитиями',
      description: 'Быт, расселение, инфраструктура общежитий',
    ),
    HandoverDepartment(
      id: 'canteen',
      title: 'Пищеблок / организация питания',
      description: 'Качество питания, режим работы столовых',
    ),
    HandoverDepartment(
      id: 'infrastructure',
      title: 'Административно-хозяйственный отдел',
      description: 'Ремонты, благоустройство, инженерные системы',
    ),
    HandoverDepartment(
      id: 'academic_office',
      title: 'Учебный отдел',
      description: 'Расписание, учебный процесс, аттестация',
    ),
    HandoverDepartment(
      id: 'security',
      title: 'Служба безопасности',
      description: 'Инциденты, пропускной режим (при необходимости)',
    ),
  ];

  static HandoverDepartment? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final d in defaults) {
      if (d.id == id) return d;
    }
    return null;
  }
}
