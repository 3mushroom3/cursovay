import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_roles.dart';

class UsersAdminPage extends StatefulWidget {
  const UsersAdminPage({super.key});

  @override
  State<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends State<UsersAdminPage> {
  /// По умолчанию — только очередь регистрации; после решения статус меняется и строка пропадает.
  String statusFilter = 'unverified';

  String statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Подтверждённая учетная запись';
      case 'unverified':
        return 'На рассмотрении';
      case 'disabled':
        return 'В регистрации отказано';
      default:
        return 'Неизвестно';
    }
  }

  String roleLabel(String role) {
    final normalized = UserRoles.normalize(role);
    switch (normalized) {
      case UserRoles.student:
        return 'Студент';
      case UserRoles.teacher:
        return 'Преподаватель';
      case UserRoles.admin:
        return 'Администратор';
      default:
        return 'Неизвестно';
    }
  }

  static String? _documentUrl(Map<String, dynamic> data) {
    final u = data['documentUrl'] ?? data['photoUrl'];
    if (u is String && u.isNotEmpty) return u;
    return null;
  }

  static Uint8List? _documentInlineImageBytes(Map<String, dynamic> data) {
    final inline = data['documentInlineBase64'];
    if (inline is! String || inline.isEmpty) return null;
    try {
      return base64Decode(inline);
    } catch (_) {
      return null;
    }
  }

  static bool _isLikelyPdf(Map<String, dynamic> data, String? url) {
    final path = data['documentPath'] as String?;
    if (path != null && path.toLowerCase().endsWith('.pdf')) return true;
    if (url != null && url.toLowerCase().contains('.pdf')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('users');

    if (statusFilter == 'all') {
      query = query.orderBy('createdAt', descending: true);
    } else {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        actions: [
          DropdownButton<String>(
            value: statusFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Все')),
              DropdownMenuItem(
                value: 'verified',
                child: Text('Подтверждённые'),
              ),
              DropdownMenuItem(
                value: 'unverified',
                child: Text('На рассмотрении'),
              ),
              DropdownMenuItem(
                value: 'disabled',
                child: Text('В регистрации отказано'),
              ),
            ],
            onChanged: (v) => setState(() => statusFilter = v!),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            final hint = statusFilter == 'unverified'
                ? 'Нет заявок со статусом «На рассмотрении». '
                    'Переключите фильтр на «Все», если ищете конкретного пользователя.'
                : 'Нет пользователей';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt']?.toDate();
              final name = data['fullName'] as String? ?? '';

              return ListTile(
                title: Text(name.isNotEmpty ? name : (data['email'] ?? '')),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty) Text(data['email'] ?? ''),
                    Text(roleLabel(data['role'] ?? '')),
                    Text(statusLabel(data['status'] ?? '')),
                    if (createdAt != null)
                      Text(
                        '${createdAt.day}.${createdAt.month}.${createdAt.year}',
                      ),
                  ],
                ),
                onTap: () => _openUserDialog(context, doc.id, data),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _openUserDialog(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) {
    final prevStatus = (data['status'] as String?) ?? 'unverified';
    String role = UserRoles.normalize(data['role'] ?? UserRoles.student);
    String status = data['status'] ?? 'unverified';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final docUrl = _documentUrl(data);
            final inlineBytes = _documentInlineImageBytes(data);
            final isPdf = _isLikelyPdf(data, docUrl);

            return AlertDialog(
              title: Text(data['email'] ?? ''),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((data['fullName'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('ФИО: ${data['fullName']}'),
                      ),
                    if (inlineBytes != null) ...[
                      const Text(
                        'Документ (из Firestore):',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          inlineBytes,
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, st) => Text(
                            'Не удалось показать изображение: $err',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (docUrl != null) ...[
                      const Text(
                        'Изображение зачетки/кабинета:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (isPdf)
                        SelectableText(
                          docUrl,
                          style: const TextStyle(fontSize: 12),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            docUrl,
                            height: 200,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (ctx, err, st) => SelectableText(
                              docUrl,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Роль'),
                      items: const [
                        DropdownMenuItem(
                          value: UserRoles.student,
                          child: Text('Студент'),
                        ),
                        DropdownMenuItem(
                          value: UserRoles.teacher,
                          child: Text('Преподаватель'),
                        ),
                        DropdownMenuItem(
                          value: UserRoles.admin,
                          child: Text('Администратор'),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => role = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: const [
                        DropdownMenuItem(
                          value: 'verified',
                          child: Text('Подтвердить регистрацию'),
                        ),
                        DropdownMenuItem(
                          value: 'unverified',
                          child: Text('На рассмотрении'),
                        ),
                        DropdownMenuItem(
                          value: 'disabled',
                          child: Text('Отказать в регистрации'),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => status = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({
                      'role': role,
                      'status': status,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    if (!mounted) return;
                    final closedRequest = prevStatus == 'unverified' &&
                        (status == 'verified' || status == 'disabled');
                    if (closedRequest) {
                      setState(() => statusFilter = 'unverified');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Заявка обработана — пользователь убран из списка ожидания',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
