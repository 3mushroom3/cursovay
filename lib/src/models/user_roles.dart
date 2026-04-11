class UserRoles {
  static const String student = 'student';
  static const String teacher = 'teacher';
  static const String admin = 'admin';

  // Legacy values from prototype versions.
  static const String legacyUser = 'user';
  static const String legacyStaff = 'staff';
  static const String legacyModerator = 'moderator';

  static String normalize(String? role) {
    if (role == null) return '';
    if (role == legacyUser) return student;
    if (role == legacyStaff || role == legacyModerator) return teacher;
    return role;
  }
}

