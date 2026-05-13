import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesRepository {
  static CollectionReference<Map<String, dynamic>> categories() {
    return FirebaseFirestore.instance.collection('categories');
  }

  static Future<String> createCategory({
    required String name,
    bool staffOnly = false,
  }) async {
    final doc = await categories().add({
      'name': name.trim(),
      'staffOnly': staffOnly,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> updateCategory({
    required String id,
    required String name,
    bool? staffOnly,
  }) async {
    final patch = <String, dynamic>{
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (staffOnly != null) patch['staffOnly'] = staffOnly;
    await categories().doc(id).update(patch);
  }

  static Future<void> deleteCategory(String id) async {
    await categories().doc(id).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchOrdered() {
    return categories().orderBy('name').snapshots();
  }
}
