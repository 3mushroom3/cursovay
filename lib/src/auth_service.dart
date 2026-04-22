import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/user_roles.dart';

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = false;
  bool get loading => _loading;

  bool _profileLoaded = false;
  bool get profileLoaded => _profileLoaded;

  User? get user => _auth.currentUser;

  Map<String, dynamic>? profile;

  Stream<User?> get authChanges => _auth.authStateChanges();

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db.collection('users').doc(uid).get();
    profile = snap.data();
    _profileLoaded = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await loadProfile();
    } finally {
      _setLoading(false);
    }
  }

  /// Лимит файла до base64. Документ пользователя в Firestore ≤ ~1 МБ; фото в [documentInlineBase64].
  static const int maxIdentityPhotoBytes = 500 * 1024;

  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    required String role,
    required PlatformFile document,
  }) async {
    _setLoading(true);
    UserCredential? cred;
    try {
      final ext = (document.extension ?? '').toLowerCase();
      if (!const {'jpg', 'jpeg', 'png'}.contains(ext)) {
        throw FormatException('Нужно фото JPG или PNG.');
      }
      final Uint8List bytes;
      if (document.bytes != null && document.bytes!.isNotEmpty) {
        bytes = document.bytes!;
      } else {
        final p = document.path;
        if (p == null || p.isEmpty) {
          throw StateError('Не удалось прочитать файл (нет пути и данных в памяти).');
        }
        bytes = await File(p).readAsBytes();
      }
      if (bytes.length > maxIdentityPhotoBytes) {
        throw FormatException(
          'Файл слишком большой (${(bytes.length / 1024).ceil()} КБ). '
          'Максимум ${maxIdentityPhotoBytes ~/ 1024} КБ — сожмите или снимите фото заново.',
        );
      }

      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final docInlineB64 = base64Encode(bytes);
      const maxB64Chars = 690000;
      if (docInlineB64.length > maxB64Chars) {
        throw FormatException(
          'Файл после кодирования не помещается в лимит Firestore. '
          'Сожмите фото примерно до ${maxIdentityPhotoBytes ~/ 1024} КБ.',
        );
      }

      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;
      final safeMiddleName = (middleName ?? '').trim();
      final safeFirstName = firstName.trim();
      final safeLastName = lastName.trim();

      await _db.collection('users').doc(uid).set({
        'email': email,
        'firstName': safeFirstName,
        'lastName': safeLastName,
        'middleName': safeMiddleName,
        'fullName': [safeLastName, safeFirstName, safeMiddleName]
            .where((part) => part.isNotEmpty)
            .join(' ')
            .trim(),
        'role': UserRoles.normalize(role),
        'status': 'unverified',
        'isVerified': false,
        'documentMime': mime,
        'documentInlineBase64': docInlineB64,
        'documentStorage': 'firestore',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await cred.user?.sendEmailVerification();

      await loadProfile();
    } on Object catch (_) {
      await _rollbackPartialSignUp(cred);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _rollbackPartialSignUp(UserCredential? cred) async {
    final u = cred?.user;
    if (u == null) return;
    try {
      await u.delete();
    } catch (_) {}
    if (_auth.currentUser != null) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    profile = null;
    _profileLoaded = false;
    notifyListeners();
  }

  bool get isAdmin => UserRoles.normalize(profile?['role']) == UserRoles.admin;

  bool get isStudent =>
      UserRoles.normalize(profile?['role']) == UserRoles.student;

  bool get isStaff => UserRoles.normalize(profile?['role']) == UserRoles.staff;

  bool get isModerator =>
      UserRoles.normalize(profile?['role']) == UserRoles.moderator;

  /// Сотрудник (включая устаревшее значение `teacher` в БД).
  bool get isTeacher => isStaff;

  /// Кто может создавать предложения по ТЗ: студент и сотрудник.
  bool get canPostProposals => isStudent || isStaff;

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> reloadUser() async {
    final current = _auth.currentUser;
    if (current == null) return;
    try {
      await current.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        await signOut();
        return;
      }
      rethrow;
    }
    await loadProfile();
  }

  Future<void> sendVerificationEmail() async {
    final current = _auth.currentUser;
    if (current == null) return;
    await current.sendEmailVerification();
  }

  static String? validatePassword(String value) {
    final v = value.trim();
    if (v.length < 8) return 'Минимум 8 символов';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Добавьте заглавную букву';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Добавьте строчную букву';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Добавьте цифру';
    return null;
  }
}