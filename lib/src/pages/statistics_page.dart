import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/proposal_status.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  String statusLabel(String status) {
    final normalized = ProposalStatus.normalize(status);
    return ProposalStatus.label(normalized);
  }

  Color statusColor(String status) {
    final normalized = ProposalStatus.normalize(status);
    switch (normalized) {
      case ProposalStatus.pending:
        return Colors.orange;
      case ProposalStatus.inProgress:
        return Colors.purple;
      case ProposalStatus.completed:
        return Colors.green;
      case ProposalStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('proposals').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final counts = <String, int>{
            ProposalStatus.pending: 0,
            ProposalStatus.inProgress: 0,
            ProposalStatus.completed: 0,
            ProposalStatus.rejected: 0,
          };

          final top = <Map<String, dynamic>>[];

          for (final doc in snapshot.data!.docs) {
            final status = (doc.data() as Map)['status'] ?? ProposalStatus.pending;
            final normalized = ProposalStatus.normalize(status as String?);
            if (counts.containsKey(normalized)) {
              counts[normalized] = counts[normalized]! + 1;
            }

            final data = doc.data() as Map;
            final votesCount = (data['votesCount'] as int?) ?? 0;
            top.add({
              'id': doc.id,
              'title': data['title'] ?? '',
              'votesCount': votesCount,
            });
          }

          final total = counts.values.fold<int>(0, (a, b) => a + b);
          if (total == 0) {
            return const Center(child: Text('Нет данных'));
          }

          top.sort((a, b) => (b['votesCount'] as int).compareTo(a['votesCount'] as int));
          final top5 = top.take(5).toList();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(
                height: 220,
                child: CustomPaint(
                  painter: _PieChartPainter(counts, statusColor),
                  child: const Center(),
                ),
              ),
              const SizedBox(height: 32),
              ...counts.entries.map((e) {
                final progress = e.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel(e.key),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: statusColor(e.key),
                        backgroundColor:
                            statusColor(e.key).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${e.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 32),
              Text('Топ по голосам', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (top5.isEmpty)
                const Text('Нет данных')
              else
                ...top5.map((e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text((e['title'] as String).toString()),
                      trailing: Text('${e['votesCount']}'),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final Color Function(String) colorOf;

  _PieChartPainter(this.data, this.colorOf);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    var startAngle = -pi / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * pi;
      paint.color = colorOf(entry.key);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}