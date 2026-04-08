import 'dart:convert';
import 'dart:io';

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

  /// Регистрация с фото для проверки; без Firebase Storage (подходит для Spark).
  /// Фото хранится в Firestore как base64 (лимит [maxIdentityPhotoBytes]).
  static const int maxIdentityPhotoBytes = 500 * 1024;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required PlatformFile document,
  }) async {
    _setLoading(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final ext = (document.extension ?? '').toLowerCase();
      if (!const {'jpg', 'jpeg', 'png'}.contains(ext)) {
        throw FormatException(
          'Нужно фото JPG или PNG. PDF на бесплатном плане не поддерживается.',
        );
      }
      final p = document.path;
      if (p == null) {
        throw StateError('Document path is null');
      }
      final bytes = await File(p).readAsBytes();
      if (bytes.length > maxIdentityPhotoBytes) {
        throw FormatException(
          'Файл слишком большой (${(bytes.length / 1024).ceil()} КБ). '
          'Максимум ${maxIdentityPhotoBytes ~/ 1024} КБ — сожмите или снимите фото заново.',
        );
      }

      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final b64 = base64Encode(bytes);

      await _db.collection('users').doc(uid).set({
        'email': email,
        'fullName': fullName.trim(),
        'role': role,
        'status': 'unverified',
        'identityPhotoBase64': b64,
        'identityPhotoMime': mime,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await loadProfile();
    } finally {
      _setLoading(false);
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
  bool get isModerator =>
      UserRoles.normalize(profile?['role']) == UserRoles.moderator;
}