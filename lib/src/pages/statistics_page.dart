import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/proposal_status.dart';
import '../widgets/dgtu_background.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  String statusLabel(String status) => ProposalStatus.label(ProposalStatus.normalize(status));

  Color statusColor(String status) {
    switch (ProposalStatus.normalize(status)) {
      case ProposalStatus.pending:
      case ProposalStatus.submitted:
        return Colors.orange;
      case ProposalStatus.inProgress:
        return Colors.purple;
      case ProposalStatus.completed:
      case ProposalStatus.closed:
        return Colors.green;
      case ProposalStatus.rejected:
        return Colors.red;
      case ProposalStatus.published:
        return Colors.teal;
      case ProposalStatus.archived:
        return Colors.blueGrey;
      case ProposalStatus.transferred:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Статистика доступна только модераторам и администраторам
    if (!auth.isModerator && !auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Статистика')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Статистика доступна\nтолько модераторам и администраторам',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: DgtuBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('proposals').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final counts = <String, int>{
              for (final s in ProposalStatus.values) s: 0,
            };
            final top = <Map<String, dynamic>>[];

            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map;
              final normalized =
                  ProposalStatus.normalize(data['status'] as String?);
              if (counts.containsKey(normalized)) {
                counts[normalized] = counts[normalized]! + 1;
              }
              final votesCount = (data['votesForCount'] as int?) ?? 0;
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

            top.sort((a, b) =>
                (b['votesCount'] as int).compareTo(a['votesCount'] as int));
            final top5 = top.take(5).toList();

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Итого предложений: $total',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: CustomPaint(
                    painter: _PieChartPainter(counts, statusColor, total),
                    child: const Center(),
                  ),
                ),
                const SizedBox(height: 32),
                ...counts.entries.where((e) => e.value > 0).map((e) {
                  final progress = e.value / total;
                  final pct = (progress * 100).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                statusLabel(e.key),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '${e.value} · $pct%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: statusColor(e.key),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          color: statusColor(e.key),
                          backgroundColor: statusColor(e.key).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                Text('Топ-5 по голосам «за»',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (top5.isEmpty)
                  const Text('Нет данных')
                else
                  ...top5.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF1370B9).withOpacity(0.15),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1370B9)),
                        ),
                      ),
                      title: Text((e['title'] as String).toString()),
                      trailing: Text(
                        '${e['votesCount']} 👍',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final Color Function(String) colorOf;
  final int total;

  _PieChartPainter(this.data, this.colorOf, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    var startAngle = -pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    final nonZero = data.entries.where((e) => e.value > 0).toList();

    for (final entry in nonZero) {
      final sweepAngle = (entry.value / total) * 2 * pi;
      paint.color = colorOf(entry.key);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Процент внутри сектора
      final pct = (entry.value / total * 100).round();
      if (pct >= 5) {
        final midAngle = startAngle + sweepAngle / 2;
        final labelR = radius * 0.65;
        final labelPos = Offset(
          center.dx + labelR * cos(midAngle),
          center.dy + labelR * sin(midAngle),
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$pct%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }

      startAngle += sweepAngle;
    }

    // Белое кольцо в центре (donut эффект)
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.40, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
