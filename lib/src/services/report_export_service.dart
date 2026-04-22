import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/proposal_status.dart';

/// Формирование отчётов для модераторов / передачи в подразделения.
///
/// Почему клиентский экспорт допустим на этапе MVP: данные уже в Firestore,
/// модератору нужен быстрый файл. В production отчёты обычно генерируют
/// на сервере (Cloud Functions + Cloud Storage), чтобы:
/// * не тащить большие выборки на телефон;
/// * единообразно подписывать документы;
/// * соблюдать retention и аудит.
///
/// Здесь — линейный обход коллекции с фильтрацией в памяти (подходит для
/// умеренного объёма; при росте — пагинация или серверный отчёт).
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
    final rows = <ReportProposalRow>[];
    for (final doc in snap.docs) {
      final m = doc.data();
      final created = (m['createdAt'] as Timestamp?)?.toDate();
      if (from != null && created != null && created.isBefore(from)) continue;
      if (to != null && created != null && created.isAfter(to)) continue;
      final cat = m['categoryId'] as String? ?? '';
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          categoryId != 'all' &&
          cat != categoryId) {
        continue;
      }
      final votesForCount = (m['votesForCount'] as int?) ?? 0;
      final votesAgainstCount = (m['votesAgainstCount'] as int?) ?? 0;
      final legacyVotes = (m['votesCount'] as int?) ?? 0;
      rows.add(
        ReportProposalRow(
          id: doc.id,
          title: m['title'] as String? ?? '',
          text: m['text'] as String? ?? '',
          status: ProposalStatus.normalize(m['status'] as String?),
          categoryId: cat,
          authorId: m['authorId'] as String? ?? '',
          votesCount: legacyVotes,
          votesForCount: votesForCount == 0 && votesAgainstCount == 0
              ? legacyVotes
              : votesForCount,
          votesAgainstCount: votesAgainstCount,
          moderationPublished: m['moderationPublished'] as bool?,
          createdAt: created,
        ),
      );
    }
    return rows;
  }

  /// Имена категорий для подписей в отчёте (один запрос ко всем категориям).
  Future<Map<String, String>> categoryNameMap() async {
    final snap = await _db.collection('categories').get();
    final map = <String, String>{};
    for (final d in snap.docs) {
      map[d.id] = d.data()['name'] as String? ?? d.id;
    }
    return map;
  }

  Future<File> buildPdf({
    required List<ReportProposalRow> rows,
    required Map<String, String> categoryNames,
    required String title,
  }) async {
    final pdf = pw.Document();
    final tableData = <List<String>>[
      [
        'ID',
        'Title',
        'Status',
        'Category',
        'Votes For',
        'Votes Against',
        'Public',
        'Created At',
      ],
    ];
    for (final r in rows) {
      tableData.add([
        r.id,
        _safeText(r.title),
        _safeText(ProposalStatus.label(r.status)),
        _safeText(categoryNames[r.categoryId] ?? r.categoryId),
        '${r.votesForCount}',
        '${r.votesAgainstCount}',
        r.moderationPublished == true
            ? 'yes'
            : r.moderationPublished == false
                ? 'no'
                : 'legacy',
        r.createdAt?.toIso8601String() ?? '',
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
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
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
    final sheet = excel[sheetTitle.length > 31 ? sheetTitle.substring(0, 31) : sheetTitle];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Title'),
      TextCellValue('Text'),
      TextCellValue('Status'),
      TextCellValue('Category'),
      TextCellValue('Author (uid)'),
      TextCellValue('Votes For'),
      TextCellValue('Votes Against'),
      TextCellValue('Public Moderation'),
      TextCellValue('Created At'),
    ]);

    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r.id),
        TextCellValue(_safeText(r.title)),
        TextCellValue(_safeText(r.text)),
        TextCellValue(_safeText(ProposalStatus.label(r.status))),
        TextCellValue(_safeText(categoryNames[r.categoryId] ?? r.categoryId)),
        TextCellValue(r.authorId),
        IntCellValue(r.votesForCount),
        IntCellValue(r.votesAgainstCount),
        TextCellValue(
          r.moderationPublished == true
              ? 'yes'
              : r.moderationPublished == false
                  ? 'no'
                  : 'legacy',
        ),
        TextCellValue(r.createdAt?.toIso8601String() ?? ''),
      ]);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Не удалось сформировать XLSX');
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }
}

/// Строка отчёта: плоская проекция документа Firestore.
class ReportProposalRow {
  const ReportProposalRow({
    required this.id,
    required this.title,
    required this.text,
    required this.status,
    required this.categoryId,
    required this.authorId,
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
  final int votesCount;
  final int votesForCount;
  final int votesAgainstCount;
  final bool? moderationPublished;
  final DateTime? createdAt;
}

String _safeText(String input) {
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
      if (ch == lower) {
        b.write(t);
      } else {
        b.write(t.isEmpty ? '' : '${t[0].toUpperCase()}${t.substring(1)}');
      }
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}
