import 'package:cloud_firestore/cloud_firestore.dart';

/// Профиль пользователя: предпочтения, не связанные напрямую с аутентификацией.
///
/// Вынесено из [AuthService], чтобы не раздувать сервис авторизации и не смешивать
/// домены «логин» и «настройки уведомлений».
class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Id категорий, по которым пользователь хочет получать push (см. FCM topics).
  Future<void> setFavoriteCategoryIds({
    required String uid,
    required List<String> categoryIds,
  }) async {
    await userDoc(uid).set(
      {
        'favoriteCategoryIds': categoryIds,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
