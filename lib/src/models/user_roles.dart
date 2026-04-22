/// Роли пользователей в системе (хранятся в `users.role` в Firestore).
///
/// История: в раннем прототипе использовались `teacher`, `user`, `staff`, `moderator`.
/// Сохраняем обратную совместимость через [normalize], чтобы старые документы
/// не ломали авторизацию после обновления приложения.
class UserRoles {
  static const String student = 'student';
  static const String staff = 'staff';
  static const String moderator = 'moderator';
  static const String admin = 'admin';

  /// Устаревшее имя «сотрудник» в старых данных.
  static const String teacher = 'teacher';

  // Legacy values from prototype versions.
  static const String legacyUser = 'user';
  static const String legacyStaff = 'staff';
  static const String legacyModerator = 'moderator';

  /// Все роли, которые можно выставить администратором вручную.
  static const List<String> assignableByAdmin = [
    student,
    staff,
    moderator,
    admin,
  ];

  /// Роли, доступные при самостоятельной регистрации (модератор/админ — только из админки).
  static const List<String> selfRegistrationRoles = [
    student,
    staff,
  ];

  static String normalize(String? role) {
    if (role == null || role.isEmpty) return '';
    if (role == legacyUser) return student;
    if (role == legacyStaff) return staff;
    if (role == legacyModerator) return moderator;
    if (role == teacher) return staff;
    return role;
  }

  static String labelRu(String? role) {
    switch (normalize(role)) {
      case student:
        return 'Студент';
      case staff:
        return 'Сотрудник';
      case moderator:
        return 'Модератор';
      case admin:
        return 'Администратор';
      default:
        return 'Неизвестно';
    }
  }
}
