import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesRepository {
  static CollectionReference<Map<String, dynamic>> categories() {
    return FirebaseFirestore.instance.collection('categories');
  }

  static Future<String> createCategory({required String name}) async {
    final doc = await categories().add({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> updateCategory({
    required String id,
    required String name,
  }) async {
    await categories().doc(id).update({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteCategory(String id) async {
    await categories().doc(id).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchOrdered() {
    return categories().orderBy('name').snapshots();
  }
}
