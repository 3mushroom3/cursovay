/// Политика отображения предложений в «общей ленте» и участия в голосовании.
///
/// После внедрения модерации новые документы получают `moderationPublished`.
/// Старые документы без поля считаем «наследием»: если `visibility == public`,
/// поведение не ломаем (обратная совместимость).
class PublicFeedPolicy {
  const PublicFeedPolicy._();

  /// Видят ли посторонние пользователи карточку в общей ленте.
  static bool isVisibleToOthers(Map<String, dynamic> data) {
    if (data['visibility'] != 'public') return false;
    final mp = data['moderationPublished'];
    if (mp == null) return true;
    return mp == true;
  }

  /// Автор всегда видит свои материалы; модератор/администратор — все.
  static bool isVisibleInFeed({
    required Map<String, dynamic> data,
    required String? currentUserId,
    bool isModerator = false,
  }) {
    if (isModerator) return true;
    final authorId = data['authorId'] as String?;
    if (currentUserId != null && authorId == currentUserId) return true;
    return isVisibleToOthers(data);
  }

  /// Участвует ли предложение в публичном голосовании (отдельная страница).
  static bool isEligibleForPublicVoting({
    required Map<String, dynamic> data,
    required String? voterId,
  }) {
    if (voterId == null) return false;
    final authorId = data['authorId'] as String?;
    if (authorId == voterId) return false;
    return isVisibleToOthers(data);
  }
}
