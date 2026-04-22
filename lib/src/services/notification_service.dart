import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  /// Имя FCM-топика для категории. Должно удовлетворять ограничениям Firebase.
  ///
  /// Почему префикс: избегаем коллизий с системными топиками и упрощаем отладку.
  static String topicNameForCategory(String categoryId) {
    final safe = categoryId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'cat_$safe';
  }

  /// Подписка на топики избранных категорий и отписка от лишних.
  ///
  /// Передайте **старый** и **новый** список id категорий из UI, чтобы корректно
  /// отписаться от топиков, которые пользователь снял с избранного.
  ///
  /// Серверная часть: Cloud Function при создании `proposals/{id}` шлёт сообщение
  /// в топик `topicNameForCategory(categoryId)`. Без такой функции клиентская
  /// подписка не даст эффекта.
  static Future<void> applyFavoriteCategoryTopics({
    required List<String> previousIds,
    required List<String> nextIds,
  }) async {
    final oldT = previousIds.map(topicNameForCategory).toSet();
    final newT = nextIds.map(topicNameForCategory).toSet();
    try {
      for (final t in oldT.difference(newT)) {
        await _messaging.unsubscribeFromTopic(t);
      }
      for (final t in newT.difference(oldT)) {
        await _messaging.subscribeToTopic(t);
      }
    } catch (_) {
      // Не блокируем сохранение профиля при сбое FCM.
    }
  }

  static Future<void> initAndSaveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      try {
        await _messaging.requestPermission();
      } catch (_) {
        // Permission request may already be in progress; token retrieval can still work.
      }
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': {token: true},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // В бесплатном/локальном режиме без настроенного FCM не ломаем приложение.
    }
  }
}

