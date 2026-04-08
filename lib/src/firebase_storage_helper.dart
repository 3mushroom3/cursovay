import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Возвращает [FirebaseStorage] для дефолтного бакета проекта.
///
/// Если в [FirebaseOptions.storageBucket] указан домен `*.firebasestorage.app`,
/// некоторые проекты получают HTTP 404 на старте resumable upload. В этом случае
/// используется каноническое имя `gs://<projectId>.appspot.com` (тот же бакет в GCS).
FirebaseStorage projectFirebaseStorage() {
  final options = Firebase.app().options;
  final projectId = options.projectId;
  if (projectId == null || projectId.isEmpty) {
    return FirebaseStorage.instance;
  }
  final bucket = options.storageBucket ?? '';
  if (bucket.contains('.appspot.com')) {
    return FirebaseStorage.instance;
  }
  return FirebaseStorage.instanceFor(bucket: 'gs://$projectId.appspot.com');
}
