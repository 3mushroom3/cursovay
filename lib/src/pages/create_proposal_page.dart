import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/proposal_status.dart';
import '../models/user_roles.dart';
import '../repositories/categories_repository.dart';
import '../repositories/proposals_repository.dart';

/// Create or edit a proposal.
class CreateProposalPage extends StatefulWidget {
  const CreateProposalPage({super.key, this.proposalId});

  final String? proposalId;

  @override
  State<CreateProposalPage> createState() => _CreateProposalPageState();
}

class _CreateProposalPageState extends State<CreateProposalPage> {
  final _title = TextEditingController();
  final _text = TextEditingController();

  String? _categoryId;
  bool _loadingDoc = false;
  String? _loadError;

  final List<PlatformFile> _picked = [];
  bool _saving = false;
  bool _visibilityPublic = true;

  static const _uncategorized = 'uncategorized';
  static const int _maxAttachmentBytes = 500 * 1024;

  @override
  void initState() {
    super.initState();
    if (widget.proposalId != null) {
      _loadExisting();
    } else {
      _categoryId = _uncategorized;
    }
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loadingDoc = true;
      _loadError = null;
    });
    try {
      final snap = await ProposalsRepository.proposals()
          .doc(widget.proposalId!)
          .get();
      if (!snap.exists) {
        setState(() {
          _loadError = 'Предложение не найдено';
          _loadingDoc = false;
        });
        return;
      }
      final d = snap.data()!;
      _title.text = d['title'] as String? ?? '';
      _text.text = d['text'] as String? ?? '';
      _categoryId = d['categoryId'] as String? ?? _uncategorized;
      _visibilityPublic =
          (d['visibility'] as String? ?? 'private') == 'public';
    } catch (e) {
      setState(() => _loadError = 'Ошибка загрузки');
    } finally {
      if (mounted) setState(() => _loadingDoc = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() {
      for (final f in r.files) {
        if ((f.bytes != null && f.bytes!.isNotEmpty) ||
            (f.path != null && f.path!.isNotEmpty)) {
          _picked.add(f);
        }
      }
    });
  }

  Future<Uint8List> _readFileBytes(PlatformFile f) async {
    if (f.bytes != null && f.bytes!.isNotEmpty) return f.bytes!;
    final p = f.path;
    if (p == null || p.isEmpty) throw StateError('Нет данных файла');
    return File(p).readAsBytes();
  }

  Future<List<Map<String, dynamic>>> _encodeAttachments() async {
    final out = <Map<String, dynamic>>[];
    for (final f in _picked) {
      final ext = (f.extension ?? '').toLowerCase();
      if (!const {'jpg', 'jpeg', 'png'}.contains(ext)) {
        throw FormatException('Можно прикреплять только фото (JPG/PNG).');
      }
      final bytes = await _readFileBytes(f);
      if (bytes.length > _maxAttachmentBytes) {
        throw FormatException(
          'Фото «${f.name}» слишком большое (${(bytes.length / 1024).ceil()} КБ). '
          'Максимум ${_maxAttachmentBytes ~/ 1024} КБ.',
        );
      }
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final objectName = '${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      final inline = base64Encode(bytes);
      out.add({
        'name': f.name.isNotEmpty ? f.name : objectName,
        'contentType': mime,
        'inlineBase64': inline,
        'storage': 'firestore',
      });
    }
    return out;
  }

  Future<void> _save({required String status}) async {
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    if (_title.text.trim().isEmpty || _text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните тему и описание')),
      );
      return;
    }

    final cat = _categoryId ?? _uncategorized;

    setState(() => _saving = true);
    try {
      String proposalId;

      if (widget.proposalId == null) {
        final ref = await ProposalsRepository.createProposal(
          title: _title.text.trim(),
          text: _text.text.trim(),
          authorId: uid,
          categoryId: cat,
          visibility: _visibilityPublic ? 'public' : 'private',
          status: status,
        );
        proposalId = ref.id;
      } else {
        proposalId = widget.proposalId!;
        final snap =
            await ProposalsRepository.proposals().doc(proposalId).get();
        final st = snap.data()?['status'] as String?;
        if (st != ProposalStatus.pending && st != ProposalStatus.submitted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Редактирование недоступно для этого статуса')),
            );
          }
          return;
        }
        await ProposalsRepository.updateProposalContent(
          proposalId: proposalId,
          title: _title.text.trim(),
          text: _text.text.trim(),
          categoryId: cat,
        );
        await ProposalsRepository.proposals().doc(proposalId).update({
          'visibility': _visibilityPublic ? 'public' : 'private',
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (_picked.isNotEmpty) {
        final encoded = await _encodeAttachments();
        await ProposalsRepository.appendAttachments(
          proposalId: proposalId,
          items: encoded,
        );
        _picked.clear();
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException ? e.message : 'Ошибка сохранения'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDoc) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Редактирование')),
        body: Center(child: Text(_loadError!)),
      );
    }

    final auth = context.watch<AuthService>();
    final role = UserRoles.normalize(auth.profile?['role']);
    final isStaffOrAbove = role == UserRoles.staff ||
        role == UserRoles.moderator ||
        role == UserRoles.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.proposalId == null ? 'Новое предложение' : 'Редактирование'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Тема',
                hintText: 'Например: Улучшить освещение в корпусе А',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              decoration: const InputDecoration(
                labelText: 'Текст предложения',
                hintText:
                    'Опишите проблему и предложите решение. Чем подробнее — тем лучше.',
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: CategoriesRepository.watchOrdered(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final allDocs = snapshot.data!.docs;
                // Студенты не видят категории только для преподавателей
                final docs = allDocs.where((d) {
                  final staffOnly = d.data()['staffOnly'] as bool? ?? false;
                  return !staffOnly || isStaffOrAbove;
                }).toList();

                final items = <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: _uncategorized,
                    child: Text('Без категории'),
                  ),
                  ...docs.map(
                    (d) {
                      final isStaff =
                          d.data()['staffOnly'] as bool? ?? false;
                      return DropdownMenuItem(
                        value: d.id,
                        child: Row(
                          children: [
                            if (isStaff) ...[
                              const Icon(Icons.school_outlined,
                                  size: 16, color: Color(0xFF1370B9)),
                              const SizedBox(width: 6),
                            ],
                            Text(d.data()['name'] as String? ?? d.id),
                          ],
                        ),
                      );
                    },
                  ),
                ];
                return DropdownButtonFormField<String>(
                  value: _categoryId != null &&
                          items.any((e) => e.value == _categoryId)
                      ? _categoryId
                      : _uncategorized,
                  decoration: const InputDecoration(labelText: 'Категория'),
                  items: items,
                  onChanged:
                      _saving ? null : (v) => setState(() => _categoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _picked.isEmpty
                    ? 'Прикрепить фото (JPG/PNG, до ${_maxAttachmentBytes ~/ 1024} КБ)'
                    : 'Файлов выбрано: ${_picked.length}',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Суммарно не более ~500 КБ изображений на предложение.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Запросить публичный доступ'),
              subtitle: const Text(
                'Публикация в общую ленту и голосование — после проверки модератором.',
              ),
              value: _visibilityPublic,
              onChanged: _saving ? null : (v) => setState(() => _visibilityPublic = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  _saving ? null : () => _save(status: ProposalStatus.submitted),
              child: const Text('Отправить предложение'),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
