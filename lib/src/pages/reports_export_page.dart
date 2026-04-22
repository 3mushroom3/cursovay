import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../repositories/categories_repository.dart';
import '../services/report_export_service.dart';

/// Экран выгрузки отчётов (PDF / XLSX) для модераторов и администраторов.
///
/// В production сюда же добавляют сохранение в Cloud Storage и журнал выгрузок.
class ReportsExportPage extends StatefulWidget {
  const ReportsExportPage({super.key});

  @override
  State<ReportsExportPage> createState() => _ReportsExportPageState();
}

class _ReportsExportPageState extends State<ReportsExportPage> {
  DateTime? _from;
  DateTime? _to;
  String _categoryId = 'all';
  bool _busy = false;

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _to = d);
  }

  Future<void> _exportPdf() => _export(_ExportKind.pdf);
  Future<void> _exportXlsx() => _export(_ExportKind.xlsx);

  Future<void> _export(_ExportKind kind) async {
    setState(() => _busy = true);
    try {
      final svc = ReportExportService();
      final rows = await svc.loadRows(from: _from, to: _to, categoryId: _categoryId);
      final names = await svc.categoryNameMap();
      final title =
          'Отчёт предложений ${DateTime.now().toIso8601String().split('T').first}';
      switch (kind) {
        case _ExportKind.pdf:
          final f = await svc.buildPdf(rows: rows, categoryNames: names, title: title);
          await svc.shareFile(f);
          break;
        case _ExportKind.xlsx:
          final f = await svc.buildXlsx(
            rows: rows,
            categoryNames: names,
            sheetTitle: 'Отчёт',
          );
          await svc.shareFile(f);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл сформирован — откройте системный диалог')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isModerator && !auth.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Нет доступа')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты для подразделений')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Выберите период и категорию. Данные читаются из Firestore и '
            'попадают в файл для передачи (PDF или XLSX).',
          ),
          const SizedBox(height: 24),
          ListTile(
            title: Text(_from == null ? 'Дата с…' : 'С: ${_from!.toLocal()}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _busy ? null : _pickFrom,
          ),
          ListTile(
            title: Text(_to == null ? 'Дата по…' : 'По: ${_to!.toLocal()}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _busy ? null : _pickTo,
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: CategoriesRepository.watchOrdered(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              final docs = snap.data!.docs;
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Категория'),
                value: _categoryId,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Все')),
                  ...docs.map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.data()['name'] as String? ?? d.id),
                    ),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _categoryId = v ?? 'all'),
              );
            },
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _busy ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Сформировать PDF'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _exportXlsx,
            icon: const Icon(Icons.table_chart),
            label: const Text('Сформировать XLSX'),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

enum _ExportKind { pdf, xlsx }
