class UserRoles {
  // Target roles for the diploma (student/staff + responsible/admin).
  static const String student = 'student';
  static const String staff = 'staff';
  static const String moderator = 'moderator';
  static const String admin = 'admin';

  // Legacy role value used in the existing prototype.
  static const String legacyUser = 'user';

  static String normalize(String? role) {
    if (role == null) return '';
    if (role == legacyUser) return student;
    return role;
  }
}

