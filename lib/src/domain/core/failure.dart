/// Базовый тип ошибки доменного слоя.
///
/// Почему отдельный тип, а не `Exception`: в чистой архитектуре домен не должен
/// зависеть от Flutter/Firebase. Слой `data` мапит инфраструктурные сбои
/// (`FirebaseException`, сеть) в понятные для UI/бизнес-логики сообщения.
class Failure implements Exception {
  const Failure(this.message, {this.code});

  /// Человекочитаемое описание (можно показывать пользователю или логировать).
  final String message;

  /// Необязательный машинный код (например `permission-denied`).
  final String? code;

  @override
  String toString() => 'Failure($code): $message';
}
