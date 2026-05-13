class Category {
  final String id;
  final String name;
  final bool staffOnly;

  const Category({
    required this.id,
    required this.name,
    this.staffOnly = false,
  });

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: data['name'] as String? ?? id,
      staffOnly: data['staffOnly'] as bool? ?? false,
    );
  }
}
