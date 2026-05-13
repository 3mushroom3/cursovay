import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/proposal_status.dart';

class ReportExportService {
  ReportExportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Загружает предложения и отфильтровывает по периоду и категории.
  Future<List<ReportProposalRow>> loadRows({
    DateTime? from,
    DateTime? to,
    String? categoryId,
  }) async {
    final snap = await _db.collection('proposals').orderBy('createdAt').get();

    // Загружаем профили пользователей одним запросом
    final userSnap = await _db.collection('users').get();
    final userMap = <String, Map<String, dynamic>>{};
    for (final u in userSnap.docs) {
      userMap[u.id] = u.data();
    }

    final rows = <ReportProposalRow>[];
    for (final doc in snap.docs) {
      final m = doc.data();
      final created = (m['createdAt'] as Timestamp?)?.toDate();
      if (from != null && created != null && created.isBefore(from)) continue;
      if (to != null && created != null) {
        final endOfDay = to.add(const Duration(days: 1));
        if (created.isAfter(endOfDay)) continue;
      }
      final cat = m['categoryId'] as String? ?? '';
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          categoryId != 'all' &&
          cat != categoryId) {
        continue;
      }

      final authorId = m['authorId'] as String? ?? '';
      final authorProfile = userMap[authorId] ?? {};
      final authorEmail = authorProfile['email'] as String? ?? '';
      final authorFullName = (authorProfile['fullName'] as String?)?.trim() ?? '';
      final authorRole = authorProfile['role'] as String? ?? '';

      final votesForCount = (m['votesForCount'] as int?) ?? 0;
      final votesAgainstCount = (m['votesAgainstCount'] as int?) ?? 0;
      final legacyVotes = (m['votesCount'] as int?) ?? 0;

      rows.add(ReportProposalRow(
        id: doc.id,
        title: m['title'] as String? ?? '',
        text: m['text'] as String? ?? '',
        status: ProposalStatus.normalize(m['status'] as String?),
        categoryId: cat,
        authorId: authorId,
        authorEmail: authorEmail,
        authorFullName: authorFullName,
        authorRole: authorRole,
        votesCount: legacyVotes,
        votesForCount: votesForCount == 0 && votesAgainstCount == 0
            ? legacyVotes
            : votesForCount,
        votesAgainstCount: votesAgainstCount,
        moderationPublished: m['moderationPublished'] as bool?,
        createdAt: created,
      ));
    }
    return rows;
  }

  Future<Map<String, String>> categoryNameMap() async {
    final snap = await _db.collection('categories').get();
    return {for (final d in snap.docs) d.id: d.data()['name'] as String? ?? d.id};
  }

  Future<File> buildPdf({
    required List<ReportProposalRow> rows,
    required Map<String, String> categoryNames,
    required String title,
  }) async {
    final pdf = pw.Document();
    final headers = [
      'ФИО автора',
      'Email автора',
      'Роль',
      'Название предложения',
      'Тема (категория)',
      'Статус',
      'За',
      'Против',
      'Опубликовано',
      'Дата',
    ];
    final tableData = <List<String>>[headers];
    for (final r in rows) {
      tableData.add([
        _safe(r.authorFullName.isNotEmpty ? r.authorFullName : r.authorId),
        _safe(r.authorEmail),
        _safe(_roleLabel(r.authorRole)),
        _safe(r.title),
        _safe(categoryNames[r.categoryId] ?? r.categoryId),
        _safe(ProposalStatus.label(r.status)),
        '${r.votesForCount}',
        '${r.votesAgainstCount}',
        r.moderationPublished == true ? 'да' : 'нет',
        r.createdAt != null ? _formatDate(r.createdAt!) : '',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text(title)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: tableData.first,
            data: tableData.skip(1).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1),
              8: const pw.FlexColumnWidth(1),
              9: const pw.FlexColumnWidth(1.5),
            },
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> buildXlsx({
    required List<ReportProposalRow> rows,
    required Map<String, String> categoryNames,
    required String sheetTitle,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel[
        sheetTitle.length > 31 ? sheetTitle.substring(0, 31) : sheetTitle];

    sheet.appendRow([
      TextCellValue('ФИО автора'),
      TextCellValue('Email автора'),
      TextCellValue('Роль автора'),
      TextCellValue('Название предложения'),
      TextCellValue('Тема (категория)'),
      TextCellValue('Текст'),
      TextCellValue('Статус'),
      TextCellValue('Голосов за'),
      TextCellValue('Голосов против'),
      TextCellValue('Опубликовано'),
      TextCellValue('Дата создания'),
    ]);

    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r.authorFullName.isNotEmpty ? r.authorFullName : r.authorId),
        TextCellValue(r.authorEmail),
        TextCellValue(_roleLabel(r.authorRole)),
        TextCellValue(_safe(r.title)),
        TextCellValue(_safe(categoryNames[r.categoryId] ?? r.categoryId)),
        TextCellValue(_safe(r.text)),
        TextCellValue(_safe(ProposalStatus.label(r.status))),
        IntCellValue(r.votesForCount),
        IntCellValue(r.votesAgainstCount),
        TextCellValue(r.moderationPublished == true ? 'да' : 'нет'),
        TextCellValue(r.createdAt != null ? _formatDate(r.createdAt!) : ''),
      ]);
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Не удалось сформировать XLSX');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }
}

class ReportProposalRow {
  const ReportProposalRow({
    required this.id,
    required this.title,
    required this.text,
    required this.status,
    required this.categoryId,
    required this.authorId,
    required this.authorEmail,
    required this.authorFullName,
    required this.authorRole,
    required this.votesCount,
    required this.votesForCount,
    required this.votesAgainstCount,
    required this.moderationPublished,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String text;
  final String status;
  final String categoryId;
  final String authorId;
  final String authorEmail;
  final String authorFullName;
  final String authorRole;
  final int votesCount;
  final int votesForCount;
  final int votesAgainstCount;
  final bool? moderationPublished;
  final DateTime? createdAt;
}

String _safe(String input) {
  if (input.isEmpty) return input;
  const map = <String, String>{
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  };
  final b = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final lower = ch.toLowerCase();
    if (map.containsKey(lower)) {
      final t = map[lower]!;
      b.write(ch == lower ? t : (t.isEmpty ? '' : '${t[0].toUpperCase()}${t.substring(1)}'));
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

String _roleLabel(String role) {
  switch (role) {
    case 'student':
      return 'Студент';
    case 'staff':
      return 'Преподаватель';
    case 'moderator':
      return 'Модератор';
    case 'admin':
      return 'Администратор';
    default:
      return role;
  }
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}
